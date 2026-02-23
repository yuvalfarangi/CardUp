const express = require('express');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const multer = require('multer');
const upload = multer({ storage: multer.memoryStorage() });

const router = express.Router();

// Initialize Gemini API
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

let availableModel = null;

// Helper function to get or detect model
const getModel = async () => {
    if (availableModel) return genAI.getGenerativeModel({ model: availableModel });

    try {
        const models = await genAI.listModels();
        const modelList = models.models || [];

        // Try to find a suitable model
        for (const model of modelList) {
            const modelName = model.name.split('/').pop(); // Extract name from "models/gemini-..."
            if (modelName.includes('gemini')) {
                availableModel = modelName;
                console.log(`Using model: ${modelName}`);
                return genAI.getGenerativeModel({ model: modelName });
            }
        }

        throw new Error('No suitable Gemini model found. Available models: ' + modelList.map(m => m.name).join(', '));
    } catch (error) {
        console.error('Error detecting model:', error);
        throw error;
    }
};

// GET /api/gemini/test - Test API key and list available models
router.get('/test', async (req, res) => {
    try {
        const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${process.env.GEMINI_API_KEY}`);
        const result = await response.json();

        if (!response.ok) throw new Error(result.error?.message || 'Failed to fetch models');

        res.status(200).json({
            message: 'API key is valid',
            models: result
        });
    } catch (error) {
        console.error('API test error:', error);
        res.status(500).json({ error: error.message });
    }
});

// POST /api/gemini/generate - Generate content using Gemini
router.post('/generate', async (req, res) => {
    try {
        const { prompt } = req.body;

        if (!prompt) {
            return res.status(400).json({ error: 'Prompt is required' });
        }

        const model = await getModel();
        const result = await model.generateContent(prompt);
        const response = result.response;
        const text = response.text();

        res.status(200).json({ response: text });
    } catch (error) {
        console.error('Gemini API error:', error);
        res.status(500).json({ error: error.message });
    }
});


// The field name 'file' must match the key used in your Swift postMultipart function
router.post('/cardDataExtraction', upload.single('file'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'Image file is required' });
        }

        const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

        const imagePart = {
            inlineData: {
                data: req.file.buffer.toString("base64"),
                mimeType: req.file.mimetype
            }
        };

        const prompt = `Extract all relevant information from the provided card. Return the data STRICTLY as a JSON object matching this exact structure expected by the client:
{
  "passFormat": "generic",
  "cardDetails": {
    "organizationName": "...",
    "description": "...",
    "primaryFields": [{"key": "...", "label": "...", "value": "..."}],
    "secondaryFields": [],
    "auxiliaryFields": [],
    "backFields": []
  },
  "designImage": "",
  "message": null
}
Ensure the PassKit fields (primaryFields, etc.) contain "key", "label", and "value" string properties. Do not include markdown formatting, explanations, or code blocks. Output only the raw JSON string.`;

        const result = await model.generateContent([prompt, imagePart]);
        let textResponse = result.response.text();

        textResponse = textResponse.replace(/^```json\n?/, '').replace(/\n?```$/, '').trim();

        console.log('Gemini result:', textResponse);
        res.status(200).json(JSON.parse(textResponse));

    } catch (error) {
        console.error('Gemini error:', error);
        res.status(500).json({ error: error.message });
    }
});

// router.post('/chat', async (req, res) => {
//     console.log(req.body);
//     try {
//         const { messages } = req.body;

//         if (!messages || !Array.isArray(messages) || messages.length === 0) {
//             return res.status(400).json({ error: 'Messages array is required' });
//         }

//         // Ensure you are calling getGenerativeModel directly
//         const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

//         // Map previous messages to the history format, excluding the last one
//         const history = messages.slice(0, -1).map(msg => ({
//             role: msg.role === 'model' || msg.role === 'assistant' ? 'model' : 'user',
//             parts: [{ text: msg.content }]
//         }));

//         // Start the chat session with the formatted history
//         const chat = model.startChat({ history });

//         // Send the final message
//         const lastMessage = messages[messages.length - 1].content;
//         const result = await chat.sendMessage(lastMessage);

//         console.log('Gemini Chat result:', result.response.text());
//         res.status(200).json({ response: result.response.text() });
//     } catch (error) {
//         console.error('Gemini Chat error:', error);
//         res.status(500).json({ error: error.message });
//     }
// });

module.exports = router;
