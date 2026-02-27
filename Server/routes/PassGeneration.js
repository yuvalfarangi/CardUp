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

/** Convert "#RRGGBB" to "rgb(R, G, B)" as required by Apple Wallet */
function hexToRgb(hex) {
    if (!hex || !hex.startsWith('#')) return hex || 'rgb(0, 0, 0)';
    const r = parseInt(hex.slice(1, 3), 16);
    const g = parseInt(hex.slice(3, 5), 16);
    const b = parseInt(hex.slice(5, 7), 16);
    return `rgb(${r}, ${g}, ${b})`;
}

/**
 * Derive the PassKit style from the passTypeIdentifier suffix.
 * Apple registers IDs like "pass.com.company.storeCard" — the last segment
 * tells us the style. Defaults to "generic" for unrecognised suffixes.
 */
function passStyleFromIdentifier(identifier) {
    const valid = new Set(['generic', 'storeCard', 'coupon', 'eventTicket']);
    const last = identifier.split('.').pop();
    return valid.has(last) ? last : 'generic';
}

// ---------------------------------------------------------------------------
// POST /generate-pass
// Receives a GenericPassPayload (JSON) from the iOS app and returns a signed
// .pkpass binary.
// ---------------------------------------------------------------------------
router.post('/generate-pass', async (req, res) => {
    if (!signerCert || !signerKey || !wwdr) {
        return res.status(503).json({
            error: 'Pass signing certificates are not configured. See Server/certs/.'
        });
    }

    try {
        const payload = req.body;

        // ---------------------------------------------------------------
        // Build the image map.
        // icon.png is required by Apple Wallet; all others are optional.
        // Swift's JSONEncoder encodes Data as base64 strings.
        // ---------------------------------------------------------------
        const images = {};

        if (payload.logoImageData) {
            const buf = Buffer.from(payload.logoImageData, 'base64');
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

        if (payload.bannerImageData) {
            const bannerBuf = Buffer.from(payload.bannerImageData, 'base64');
            const style = passStyleFromIdentifier(
                process.env.PASS_TYPE_IDENTIFIER || payload.passTypeIdentifier || ''
            );
            if (style === 'eventTicket') {
                images['background.png']    = bannerBuf;
                images['background@2x.png'] = bannerBuf;
                images['background@3x.png'] = bannerBuf;
            } else if (style === 'storeCard' || style === 'coupon') {
                images['strip.png']    = bannerBuf;
                images['strip@2x.png'] = bannerBuf;
                images['strip@3x.png'] = bannerBuf;
            }
        }

        // ---------------------------------------------------------------
        // Pass Type Identifier and Team ID come from env vars so the
        // server is always authoritative (the cert must match these).
        // ---------------------------------------------------------------
        const passTypeIdentifier =
            process.env.PASS_TYPE_IDENTIFIER || payload.passTypeIdentifier;
        const teamIdentifier =
            process.env.TEAM_IDENTIFIER || payload.teamIdentifier;

        // ---------------------------------------------------------------
        // Create the PKPass instance
        // ---------------------------------------------------------------
        const pass = new PKPass(
            images,
            {
                wwdr,
                signerCert,
                signerKey,
                signerKeyPassphrase: process.env.CERT_PASSPHRASE || '',
            },
            {
                formatVersion:       payload.formatVersion  || 1,
                passTypeIdentifier,
                serialNumber:        payload.serialNumber,
                teamIdentifier,
                organizationName:    payload.organizationName,
                description:         payload.description,
                ...(payload.logoText        && { logoText:        payload.logoText }),
                foregroundColor:     hexToRgb(payload.foregroundColor),
                backgroundColor:     hexToRgb(payload.backgroundColor),
                ...(payload.labelColor      && { labelColor:      hexToRgb(payload.labelColor) }),
                ...(payload.expirationDate  && { expirationDate:  payload.expirationDate }),
                ...(payload.relevantDate    && { relevantDate:    payload.relevantDate }),
            }
        );

        // Set pass style (generic | storeCard | coupon | eventTicket)
        pass.type = passStyleFromIdentifier(passTypeIdentifier);

        // ---------------------------------------------------------------
        // Add fields from the iOS payload
        // ---------------------------------------------------------------
        const fieldTypes = [
            'headerFields',
            'primaryFields',
            'secondaryFields',
            'auxiliaryFields',
            'backFields',
        ];
        for (const ft of fieldTypes) {
            const fields = payload[ft];
            if (Array.isArray(fields)) {
                for (const field of fields) {
                    pass[ft].push(field);
                }
            }
        }

        // ---------------------------------------------------------------
        // Barcode
        // ---------------------------------------------------------------
        if (payload.barcodeMessage) {
            pass.setBarcode({
                message:         payload.barcodeMessage,
                format:          payload.barcodeFormat          || 'PKBarcodeFormatQR',
                messageEncoding: payload.barcodeMessageEncoding || 'iso-8859-1',
            });
        }

        // ---------------------------------------------------------------
        // Sign and zip → return binary
        // ---------------------------------------------------------------
        const passBuffer = await pass.getAsBuffer();

        res.setHeader('Content-Type', 'application/vnd.apple.pkpass');
        res.setHeader('Content-Disposition', 'attachment; filename="pass.pkpass"');
        res.send(passBuffer);

        console.log(`✅ Signed pass for serial: ${payload.serialNumber} (${pass.type})`);
    } catch (err) {
        console.error('❌ Pass generation failed:', err);
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
