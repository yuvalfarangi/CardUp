const express = require('express');
const { GoogleGenAI } = require('@google/genai');
const multer = require('multer');
const sharp = require('sharp');
const upload = multer({ storage: multer.memoryStorage() });

const router = express.Router();

// Initialize Gemini API (new SDK)
const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

// Resize and compress an image buffer to reduce token usage and payload size
async function prepareImageBuffer(buffer) {
    const resized = await sharp(buffer)
        .resize({ width: 800, withoutEnlargement: true })
        .jpeg({ quality: 80 })
        .toBuffer();
    return { buffer: resized, mimeType: 'image/jpeg' };
}

// Retry generateContent with exponential backoff on 429 rate limit errors.
// If the API suggests a retry delay longer than 10s (e.g. quota exhausted),
// fail fast rather than making the user wait.
async function generateWithRetry(params, maxAttempts = 3) {
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
            return await ai.models.generateContent(params);
        } catch (error) {
            const isRateLimit = error.status === 429 ||
                (error.message && error.message.includes('429'));
            if (isRateLimit && attempt < maxAttempts) {
                const retryMatch = error.message && error.message.match(/retry in (\d+(?:\.\d+)?)s/i);
                const suggestedDelaySec = retryMatch ? parseFloat(retryMatch[1]) : null;
                if (suggestedDelaySec && suggestedDelaySec > 10) {
                    // Quota exhausted — retry would fail anyway, surface the error immediately
                    throw error;
                }
                const delay = Math.pow(2, attempt) * 1000;
                console.warn(`Rate limit hit. Retrying in ${delay}ms... (attempt ${attempt}/${maxAttempts})`);
                await new Promise(resolve => setTimeout(resolve, delay));
            } else {
                throw error;
            }
        }
    }
}


router.post('/cardDataExtraction', upload.single('file'), async (req, res) => {
    res.status(200).json({
        passFormat: "generic",
        cardDetails: {
            organizationName: "המכללה האקדמית להנדסה ע\"ש סמי שמעון",
            description: null,
            barcodeMessage: "324268648",
            barcodeFormat: "PKBarcodeFormatCode128",
            barcodeAltText: "324268648",
            primaryFields: [
                {
                    key: "studentName",
                    label: "שם בעל הכרטיס",
                    value: "Farangi Yuval"
                }
            ],
            secondaryFields: [
                {
                    key: "idNumber",
                    label: "תעודת זהות",
                    value: "324268648"
                },
                {
                    key: "hebrewName",
                    label: "שם מלא (עברית)",
                    value: "פאראנגי יובל חי"
                }
            ],
            auxiliaryFields: [
                {
                    key: "academicYear",
                    label: "תשפו",
                    value: "2025-2026"
                },
                {
                    key: "academicInstitution",
                    label: "שם המוסד האקדמי",
                    value: "סמי שמעון"
                }
            ],
            backFields: []
        }
    });
    //     try {
    //         if (!req.file) {
    //             return res.status(400).json({ error: 'Image file is required' });
    //         }

    //         const { buffer: resizedBuffer, mimeType: resizedMimeType } = await prepareImageBuffer(req.file.buffer);

    //         const imagePart = {
    //             inlineData: {
    //                 data: resizedBuffer.toString("base64"),
    //                 mimeType: resizedMimeType
    //             }
    //         };

    //         const prompt = `Extract card info into this exact JSON structure:
    // {
    // "passFormat": "generic",
    // "cardDetails": {
    // "organizationName": "",
    // "description": "",
    // "barcodeMessage": null,
    // "barcodeFormat": null,
    // "barcodeAltText": null,
    // "primaryFields": [{"key": "", "label": "", "value": ""}],
    // "secondaryFields": [],
    // "auxiliaryFields": [],
    // "backFields": []
    // }
    // }
    // For barcodeMessage: the exact encoded data from any visible barcode or QR code, or null if none.
    // For barcodeFormat: one of PKBarcodeFormatQR, PKBarcodeFormatCode128, PKBarcodeFormatPDF417, PKBarcodeFormatAztec based on the detected barcode type, or null.
    // For barcodeAltText: human-readable version of the barcode value, or null.
    // Output only the raw JSON. No markdown or text.`;

    //         const result = await generateWithRetry({
    //             model: "gemini-2.5-flash",
    //             contents: [{ role: "user", parts: [{ text: prompt }, imagePart] }]
    //         });

    //         let textResponse = result.text;
    //         textResponse = textResponse.replace(/^```json\n?/, '').replace(/\n?```$/, '').trim();

    //         console.log('Gemini result:', textResponse);
    //         res.status(200).json(JSON.parse(textResponse));

    //     } catch (error) {
    //         console.error('Gemini error:', error);
    //         res.status(500).json({ error: error.message });
    //     }
});

// POST /api/gemini/cardDesignGenerating - Generate an SVG card background from a card photo
router.post('/cardDesignGenerating', upload.single('file'), async (req, res) => {
    res.status(200).json({
        designSvg: `<svg width="1125" height="432" viewBox="0 0 1125 432" fill="none" xmlns="http://www.w3.org/2000/svg">
    <defs>
        <linearGradient id="backgroundGradient" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stop-color="#105973"/>
            <stop offset="100%" stop-color="#1A708F"/>
        </linearGradient>
    </defs>

    <rect x="0" y="0" width="1125" height="432" fill="url(#backgroundGradient)"/>

    <path d="M0 100 C150 70 300 150 450 120 C600 90 750 180 900 150 C1050 120 1125 100 1125 100" stroke="#60C3E5" stroke-width="2" opacity="0.25"/>
    <path d="M0 140 C150 110 300 190 450 160 C600 130 750 220 900 190 C1050 160 1125 140 1125 140" stroke="#60C3E5" stroke-width="1.8" opacity="0.2"/>
    <path d="M0 180 C150 150 300 230 450 200 C600 170 750 260 900 230 C1050 200 1125 180 1125 180" stroke="#60C3E5" stroke-width="1.6" opacity="0.15"/>
    <path d="M0 220 C150 190 300 270 450 240 C600 210 750 300 900 270 C1050 240 1125 220 1125 220" stroke="#60C3E5" stroke-width="1.4" opacity="0.1"/>
    <path d="M0 260 C150 230 300 310 450 280 C600 250 750 340 900 310 C1050 280 1125 260 1125 260" stroke="#60C3E5" stroke-width="1.2" opacity="0.08"/>
    <path d="M0 300 C150 270 300 350 450 320 C600 290 750 380 900 350 C1050 320 1125 300 1125 300" stroke="#60C3E5" stroke-width="1" opacity="0.05"/>

    <line x1="880" y1="0" x2="980" y2="80" stroke="#FFFFFF" stroke-width="3" opacity="0.15"/>
    <line x1="930" y1="0" x2="1030" y2="80" stroke="#FFFFFF" stroke-width="3" opacity="0.15"/>
    <line x1="980" y1="0" x2="1080" y2="80" stroke="#FFFFFF" stroke-width="3" opacity="0.15"/>
    <line x1="1030" y1="0" x2="1125" y2="70" stroke="#FFFFFF" stroke-width="3" opacity="0.15"/>
    <line x1="1070" y1="0" x2="1125" y2="40" stroke="#FFFFFF" stroke-width="3" opacity="0.15"/>

    <circle cx="50" cy="400" r="5" fill="#60C3E5" opacity="0.3"/>
    <circle cx="150" cy="410" r="7" fill="#60C3E5" opacity="0.25"/>
    <circle cx="280" cy="395" r="6" fill="#60C3E5" opacity="0.35"/>
    <circle cx="350" cy="405" r="5" fill="#60C3E5" opacity="0.2"/>
    <circle cx="480" cy="415" r="8" fill="#60C3E5" opacity="0.3"/>
    <circle cx="600" cy="390" r="6" fill="#60C3E5" opacity="0.25"/>
    <circle cx="720" cy="400" r="7" fill="#60C3E5" opacity="0.35"/>
    <circle cx="850" cy="410" r="5" fill="#60C3E5" opacity="0.2"/>
    <circle cx="980" cy="395" r="8" fill="#60C3E5" opacity="0.3"/>
    <circle cx="1080" cy="405" r="6" fill="#60C3E5" opacity="0.25"/>

    <polygon points="190 345 220 375 160 375" fill="#D7E560" opacity="0.25"/>
    <polygon points="200 340 215 365 185 365" fill="#FFFFFF" opacity="0.2"/>
</svg>`
    });
    //     try {
    //         if (!req.file) {
    //             return res.status(400).json({ error: 'Image file is required' });
    //         }

    //         const { buffer: resizedBuffer, mimeType: resizedMimeType } = await prepareImageBuffer(req.file.buffer);

    //         const imagePart = {
    //             inlineData: {
    //                 data: resizedBuffer.toString("base64"),
    //                 mimeType: resizedMimeType
    //             }
    //         };

    //         const prompt = `Analyze this card image and generate an SVG card background (1125x432 pixels) inspired by its visual style.
    // Use abstract shapes, gradients, and geometric patterns that reflect the card's color palette.
    // Do NOT include any text, logos, barcodes, or recognizable data from the card.
    // Output only the raw SVG code starting with <svg and ending with </svg>. No markdown, no explanation.`;

    //         const result = await generateWithRetry({
    //             model: "gemini-2.5-flash",
    //             contents: [{ role: "user", parts: [{ text: prompt }, imagePart] }]
    //         });

    //         let svgCode = result.text.trim();
    //         // Strip markdown code fences if present
    //         svgCode = svgCode.replace(/^```(?:svg|xml)?\n?/, '').replace(/\n?```$/, '').trim();

    //         console.log('Generated SVG design:\n', svgCode);

    //         res.status(200).json({ designSvg: svgCode });
    //     } catch (error) {
    //         console.error('Card design generation error:', error);
    //         res.status(500).json({ error: error.message });
    //     }
});

module.exports = router;
