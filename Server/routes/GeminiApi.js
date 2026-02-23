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
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'Image file is required' });
        }

        const { buffer: resizedBuffer, mimeType: resizedMimeType } = await prepareImageBuffer(req.file.buffer);

        const imagePart = {
            inlineData: {
                data: resizedBuffer.toString("base64"),
                mimeType: resizedMimeType
            }
        };

        const prompt = `Extract card info into this exact JSON structure:
{
"passFormat": "generic",
"cardDetails": {
"organizationName": "",
"description": "",
"primaryFields": [{"key": "", "label": "", "value": ""}],
"secondaryFields": [],
"auxiliaryFields": [],
"backFields": []
}
}
Output only the raw JSON. No markdown or text.`;

        const result = await generateWithRetry({
            model: "gemini-2.5-flash-lite",
            contents: [{ role: "user", parts: [{ text: prompt }, imagePart] }]
        });

        let textResponse = result.text;
        textResponse = textResponse.replace(/^```json\n?/, '').replace(/\n?```$/, '').trim();

        console.log('Gemini result:', textResponse);
        res.status(200).json(JSON.parse(textResponse));

    } catch (error) {
        console.error('Gemini error:', error);
        res.status(500).json({ error: error.message });
    }
});

// POST /api/gemini/cardDesignGenerating - Generate a card background image from a card photo
router.post('/cardDesignGenerating', upload.single('file'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'Image file is required' });
        }

        const { buffer: resizedBuffer, mimeType: resizedMimeType } = await prepareImageBuffer(req.file.buffer);

        const imagePart = {
            inlineData: {
                data: resizedBuffer.toString("base64"),
                mimeType: resizedMimeType
            }
        };

        const prompt = `Generate a 1125x432 card background. Use only abstract graphics, gradients, and brand patterns from the original. No text, logos, or data.`;

        const result = await generateWithRetry({
            model: "gemini-2.0-flash-exp-image-generation",
            contents: [{ role: "user", parts: [{ text: prompt }, imagePart] }],
            config: { responseModalities: ["TEXT", "IMAGE"] }
        });

        const candidates = result.candidates;
        for (const candidate of candidates) {
            for (const part of candidate.content.parts) {
                if (part.inlineData) {
                    return res.status(200).json({
                        designImage: `data:${part.inlineData.mimeType};base64,${part.inlineData.data}`
                    });
                }
            }
        }

        res.status(500).json({ error: 'No image was generated in the response' });
    } catch (error) {
        console.error('Card design generation error:', error);
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;
