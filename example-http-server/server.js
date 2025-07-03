const express = require('express');
const cors = require('cors');
const app = express();

// Enable CORS for all origins (adjust for production)
app.use(cors());
app.use(express.json());

// Simple in-memory storage for demo
const serverInfo = {
  name: 'Example HTTP MCP Server',
  version: '1.0.0'
};

// Available tools
const tools = [
  {
    name: 'get_current_time',
    description: 'Get the current time in various formats',
    inputSchema: {
      type: 'object',
      properties: {
        format: {
          type: 'string',
          description: 'Time format: iso, unix, or human',
          enum: ['iso', 'unix', 'human']
        },
        timezone: {
          type: 'string',
          description: 'Timezone (e.g., America/New_York)'
        }
      },
      required: []
    }
  },
  {
    name: 'calculate',
    description: 'Perform basic mathematical calculations',
    inputSchema: {
      type: 'object',
      properties: {
        expression: {
          type: 'string',
          description: 'Mathematical expression to evaluate'
        }
      },
      required: ['expression']
    }
  },
  {
    name: 'get_random_fact',
    description: 'Get a random interesting fact',
    inputSchema: {
      type: 'object',
      properties: {
        category: {
          type: 'string',
          description: 'Fact category',
          enum: ['science', 'history', 'technology', 'general']
        }
      },
      required: []
    }
  },
  {
    name: 'echo',
    description: 'Echo back the provided message',
    inputSchema: {
      type: 'object',
      properties: {
        message: {
          type: 'string',
          description: 'Message to echo back'
        },
        uppercase: {
          type: 'boolean',
          description: 'Convert to uppercase'
        }
      },
      required: ['message']
    }
  }
];

// Middleware for optional authentication
app.use((req, res, next) => {
  const auth = req.headers.authorization;
  
  // For demo purposes, accept any bearer token or no auth
  // In production, validate the token properly
  if (auth && !auth.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Invalid authorization format' });
  }
  
  // Log the request
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', server: serverInfo });
});

// Initialize endpoint
app.post('/initialize', (req, res) => {
  const { protocolVersion, clientInfo } = req.body;
  
  console.log(`Client connected: ${clientInfo?.name} v${clientInfo?.version}`);
  
  res.json({
    protocolVersion: protocolVersion || '1.0',
    capabilities: {
      tools: {}
    },
    serverInfo
  });
});

// List tools endpoint
app.get('/tools/list', (req, res) => {
  res.json({ tools });
});

// Call tool endpoint
app.post('/tools/call', async (req, res) => {
  const { name, arguments: args = {} } = req.body;
  
  console.log(`Tool called: ${name}`, args);
  
  try {
    let content;
    
    switch (name) {
      case 'get_current_time':
        content = handleGetCurrentTime(args);
        break;
        
      case 'calculate':
        content = handleCalculate(args);
        break;
        
      case 'get_random_fact':
        content = handleGetRandomFact(args);
        break;
        
      case 'echo':
        content = handleEcho(args);
        break;
        
      default:
        return res.status(404).json({ error: `Tool '${name}' not found` });
    }
    
    res.json({ content });
    
  } catch (error) {
    console.error(`Error in tool ${name}:`, error);
    res.status(500).json({ 
      error: 'Tool execution failed',
      details: error.message 
    });
  }
});

// Tool handlers
function handleGetCurrentTime({ format = 'iso', timezone } = {}) {
  const now = new Date();
  let timeString;
  
  switch (format) {
    case 'unix':
      timeString = Math.floor(now.getTime() / 1000).toString();
      break;
    case 'human':
      timeString = now.toLocaleString('en-US', { 
        timeZone: timezone || 'UTC',
        dateStyle: 'full',
        timeStyle: 'long'
      });
      break;
    case 'iso':
    default:
      timeString = now.toISOString();
  }
  
  return [{
    type: 'text',
    text: `Current time (${format}): ${timeString}`
  }];
}

function handleCalculate({ expression }) {
  if (!expression) {
    throw new Error('Expression is required');
  }
  
  // Simple and safe math evaluation (production should use a proper parser)
  const sanitized = expression.replace(/[^0-9+\-*/().\s]/g, '');
  
  try {
    // Note: eval is dangerous! Use a proper math parser in production
    const result = Function('"use strict"; return (' + sanitized + ')')();
    
    return [{
      type: 'text',
      text: `${expression} = ${result}`
    }];
  } catch (error) {
    throw new Error(`Invalid expression: ${expression}`);
  }
}

function handleGetRandomFact({ category = 'general' } = {}) {
  const facts = {
    science: [
      'A single bolt of lightning contains enough energy to toast 100,000 slices of bread.',
      'Octopuses have three hearts and blue blood.',
      'Bananas are berries, but strawberries aren\'t.'
    ],
    history: [
      'Oxford University is older than the Aztec Empire.',
      'Cleopatra lived closer to the Moon landing than to the construction of the Great Pyramid.',
      'The woolly mammoth was still alive when the pyramids were being built.'
    ],
    technology: [
      'The first computer bug was an actual bug - a moth trapped in a Harvard Mark II computer in 1947.',
      'Email existed before the World Wide Web.',
      'The first 1GB hard drive, released in 1980, weighed 550 pounds and cost $40,000.'
    ],
    general: [
      'There are more possible games of chess than atoms in the observable universe.',
      'A group of flamingos is called a "flamboyance".',
      'The shortest war in history lasted 38-45 minutes.'
    ]
  };
  
  const categoryFacts = facts[category] || facts.general;
  const randomFact = categoryFacts[Math.floor(Math.random() * categoryFacts.length)];
  
  return [{
    type: 'text',
    text: `${category.charAt(0).toUpperCase() + category.slice(1)} fact: ${randomFact}`
  }];
}

function handleEcho({ message, uppercase = false }) {
  if (!message) {
    throw new Error('Message is required');
  }
  
  const processedMessage = uppercase ? message.toUpperCase() : message;
  
  return [{
    type: 'text',
    text: processedMessage
  }];
}

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`
🚀 Example HTTP MCP Server running on port ${PORT}

Available endpoints:
- GET  /health          - Health check
- POST /initialize      - Initialize connection
- GET  /tools/list      - List available tools
- POST /tools/call      - Call a tool

Available tools:
${tools.map(t => `- ${t.name}: ${t.description}`).join('\n')}

Test with curl:
curl http://localhost:${PORT}/health
  `);
});