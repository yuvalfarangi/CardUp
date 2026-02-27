const express = require('express');
const { PKPass } = require('passkit-generator');
const fs = require('fs');
const path = require('path');

const router = express.Router();

// ---------------------------------------------------------------------------
// Load signing certificates once at startup.
// Place signerCert.pem, signerKey.pem, and wwdr.pem in Server/certs/
// ---------------------------------------------------------------------------
const certsDir = path.resolve(__dirname, '../certs');
let signerCert, signerKey, wwdr;

try {
    signerCert = fs.readFileSync(path.join(certsDir, 'signerCert.pem'));
    signerKey  = fs.readFileSync(path.join(certsDir, 'signerKey.pem'));
    wwdr       = fs.readFileSync(path.join(certsDir, 'wwdr.pem'));
    console.log('✅ Pass signing certificates loaded');
} catch (err) {
    console.warn('⚠️  Pass signing certificates not found in Server/certs/ —', err.message);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Convert "#RRGGBB" (or "RRGGBB" without #) to "rgb(R, G, B)" as required by Apple Wallet */
function hexToRgb(hex) {
    if (!hex) return 'rgb(0, 0, 0)';
    // Normalize: add '#' prefix if missing
    const normalized = hex.startsWith('#') ? hex : `#${hex}`;
    if (!/^#[a-fA-F0-9]{6}$/.test(normalized)) return 'rgb(0, 0, 0)';
    const r = parseInt(normalized.slice(1, 3), 16);
    const g = parseInt(normalized.slice(3, 5), 16);
    const b = parseInt(normalized.slice(5, 7), 16);
    return `rgb(${r}, ${g}, ${b})`;
}

/**
 * Derive the PassKit style from the passTypeIdentifier suffix.
 * Defaults to "generic" for unrecognised suffixes.
 */
function passStyleFromIdentifier(identifier) {
    const valid = new Set(['generic', 'storeCard', 'coupon', 'eventTicket']);
    const last = (identifier || '').split('.').pop();
    return valid.has(last) ? last : 'generic';
}

/**
 * iOS JSONEncoder uses .convertToSnakeCase, so field objects arrive with
 * snake_case keys (e.g. text_alignment, date_style).  passkit-generator
 * validates against camelCase Apple PassKit names, so we convert them back.
 */
function snakeToCamel(str) {
    return str.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
}

function convertFieldKeys(field) {
    const out = {};
    for (const [k, v] of Object.entries(field)) {
        out[snakeToCamel(k)] = v;
    }
    return out;
}

// ---------------------------------------------------------------------------
// POST /generate-pass
// Receives a GenericPassPayload (JSON) from the iOS app and returns a signed
// .pkpass binary.
//
// NOTE: iOS sends all keys in snake_case because JSONEncoder uses
//       .convertToSnakeCase.  Read every payload property using snake_case.
// ---------------------------------------------------------------------------
router.post('/generate-pass', async (req, res) => {
    if (!signerCert || !signerKey || !wwdr) {
        return res.status(503).json({
            error: 'Pass signing certificates are not configured. See Server/certs/.'
        });
    }

    try {
        const p = req.body; // all keys are snake_case

        // ---------------------------------------------------------------
        // Build the image map.
        // icon.png is required by Apple Wallet; all others are optional.
        // Swift's JSONEncoder encodes Data as base64 strings.
        // ---------------------------------------------------------------
        const images = {};

        if (p.logo_image_data) {
            const buf = Buffer.from(p.logo_image_data, 'base64');
            images['icon.png']    = buf;
            images['icon@2x.png'] = buf;
            images['icon@3x.png'] = buf;
            images['logo.png']    = buf;
            images['logo@2x.png'] = buf;
        } else {
            // Minimal 1×1 white PNG — required but won't be visible
            const placeholder = Buffer.from(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI6QAAAABJRU5ErkJggg==',
                'base64'
            );
            images['icon.png']    = placeholder;
            images['icon@2x.png'] = placeholder;
            images['icon@3x.png'] = placeholder;
        }

        // ---------------------------------------------------------------
        // Pass Type Identifier and Team ID come from env vars so the
        // server is always authoritative (the cert must match these).
        // ---------------------------------------------------------------
        const passTypeIdentifier =
            process.env.PASS_TYPE_IDENTIFIER || p.pass_type_identifier;
        const teamIdentifier =
            process.env.TEAM_IDENTIFIER || p.team_identifier;

        // Use the explicit pass_style sent by the client.
        // Fall back to identifier-derived style only when the client didn't send one.
        const validStyles = new Set(['generic', 'storeCard', 'coupon', 'eventTicket']);
        let resolvedStyle = (p.pass_style && validStyles.has(p.pass_style))
            ? p.pass_style
            : passStyleFromIdentifier(passTypeIdentifier);

        if (p.banner_image_data) {
            const bannerBuf = Buffer.from(p.banner_image_data, 'base64');
            if (resolvedStyle === 'eventTicket') {
                // EventTicket uses background.png (full-pass background)
                images['background.png']    = bannerBuf;
                images['background@2x.png'] = bannerBuf;
                images['background@3x.png'] = bannerBuf;
            } else if (resolvedStyle === 'storeCard' || resolvedStyle === 'coupon') {
                // StoreCard and Coupon use strip.png (horizontal banner below header)
                images['strip.png']    = bannerBuf;
                images['strip@2x.png'] = bannerBuf;
                images['strip@3x.png'] = bannerBuf;
            }
            // Generic passes do not support strip or background images — banner ignored.
        }

        // ---------------------------------------------------------------
        // Create the PKPass instance
        // ---------------------------------------------------------------
        const certOptions = { wwdr, signerCert, signerKey };
        if (process.env.CERT_PASSPHRASE) {
            certOptions.signerKeyPassphrase = process.env.CERT_PASSPHRASE;
        }

        const pass = new PKPass(
            images,
            certOptions,
            {
                formatVersion:    p.format_version    || 1,
                passTypeIdentifier,
                serialNumber:     p.serial_number     || `card-${Date.now()}`,
                teamIdentifier,
                organizationName: p.organization_name || 'CardUp',
                description:      p.description       || 'Card',
                ...(p.logo_text       && { logoText:        p.logo_text }),
                foregroundColor:  hexToRgb(p.foreground_color),
                backgroundColor:  hexToRgb(p.background_color),
                ...(p.label_color     && { labelColor:      hexToRgb(p.label_color) }),
                ...(p.expiration_date && { expirationDate:  p.expiration_date }),
                ...(p.relevant_date   && { relevantDate:    p.relevant_date }),
            }
        );

        // Set pass style (generic | storeCard | coupon | eventTicket)
        pass.type = resolvedStyle;

        // ---------------------------------------------------------------
        // Add fields from the iOS payload.
        // Field object keys also arrive snake_case; convert to camelCase
        // so passkit-generator's Joi schema accepts them.
        // ---------------------------------------------------------------
        const fieldMap = {
            header_fields:    'headerFields',
            primary_fields:   'primaryFields',
            secondary_fields: 'secondaryFields',
            auxiliary_fields: 'auxiliaryFields',
            back_fields:      'backFields',
        };
        for (const [snakeKey, camelKey] of Object.entries(fieldMap)) {
            const fields = p[snakeKey];
            if (Array.isArray(fields)) {
                for (const field of fields) {
                    pass[camelKey].push(convertFieldKeys(field));
                }
            }
        }

        // ---------------------------------------------------------------
        // Barcode
        // ---------------------------------------------------------------
        if (p.barcode_message) {
            pass.setBarcodes({
                message:         p.barcode_message,
                format:          p.barcode_format           || 'PKBarcodeFormatQR',
                messageEncoding: p.barcode_message_encoding || 'iso-8859-1',
            });
        }

        // ---------------------------------------------------------------
        // Sign and zip → return binary (synchronous in v3)
        // ---------------------------------------------------------------
        const passBuffer = pass.getAsBuffer();

        res.setHeader('Content-Type', 'application/vnd.apple.pkpass');
        res.setHeader('Content-Disposition', 'attachment; filename="pass.pkpass"');
        res.send(passBuffer);

        console.log(`✅ Signed pass for serial: ${p.serial_number} (${pass.type})`);
    } catch (err) {
        console.error('❌ Pass generation failed:', err);
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
