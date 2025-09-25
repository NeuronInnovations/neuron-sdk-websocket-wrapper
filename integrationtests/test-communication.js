#!/usr/bin/env node

/**
 * Comprehensive test script for buyer-seller communication
 * This script:
 * 1. Starts the seller first
 * 2. Starts the buyer second  
 * 3. Sends P2P messages between them
 * 4. Checks status of both nodes
 * 5. Cleans up and exits
 */

const { spawn } = require('child_process');
const WebSocket = require('ws');
const fs = require('fs');
const path = require('path');

// Configuration
const CONFIG = {
    SELLER_WS_PORT: 3001,
    BUYER_WS_PORT: 3002,
    SELLER_P2P_PORT: 1354,
    BUYER_P2P_PORT: 1355,
    SELLER_PUBLIC_KEY: "0278b309d9b02ade112cdda215cd79da90916c940359cce783ae0b1779135f85ae",
    BUYER_PUBLIC_KEY: "02c7370bf416ee6e9f9a430a12869c456d93db6b7392a9f90d0db8981190f47153",
    TEST_MESSAGE: "Hello from seller to buyer - automated test message",
    RESPONSE_MESSAGE: "Hello from buyer to seller - automated response message"
};

// Colors for console output
const colors = {
    reset: '\x1b[0m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m'
};

// Utility functions
function log(message, color = 'reset') {
    const timestamp = new Date().toLocaleTimeString();
    console.log(`${colors.blue}[${timestamp}]${colors.reset} ${colors[color]}${message}${colors.reset}`);
}

function logSuccess(message) {
    log(`[SUCCESS] ${message}`, 'green');
}

function logError(message) {
    log(`[ERROR] ${message}`, 'red');
}

function logWarning(message) {
    log(`[WARNING] ${message}`, 'yellow');
}

// Process management
let sellerProcess = null;
let buyerProcess = null;

// Cleanup function
function cleanup() {
    log('Cleaning up processes...', 'yellow');
    
    if (sellerProcess) {
        sellerProcess.kill('SIGTERM');
        sellerProcess = null;
    }
    
    if (buyerProcess) {
        buyerProcess.kill('SIGTERM');
        buyerProcess = null;
    }
    
    // Kill any remaining processes on our ports
    try {
        require('child_process').execSync(`lsof -ti:${CONFIG.SELLER_WS_PORT} | xargs kill -9 2>/dev/null || true`);
        require('child_process').execSync(`lsof -ti:${CONFIG.BUYER_WS_PORT} | xargs kill -9 2>/dev/null || true`);
        require('child_process').execSync(`lsof -ti:${CONFIG.SELLER_P2P_PORT} | xargs kill -9 2>/dev/null || true`);
        require('child_process').execSync(`lsof -ti:${CONFIG.BUYER_P2P_PORT} | xargs kill -9 2>/dev/null || true`);
    } catch (e) {
        // Ignore errors
    }
    
    logSuccess('Cleanup completed');
}

// Set up cleanup on exit
process.on('SIGINT', cleanup);
process.on('SIGTERM', cleanup);
process.on('exit', cleanup);

// WebSocket helper functions
function createWebSocket(url) {
    return new Promise((resolve, reject) => {
        const ws = new WebSocket(url);
        
        ws.on('open', () => {
            logSuccess(`Connected to ${url}`);
            resolve(ws);
        });
        
        ws.on('error', (error) => {
            logError(`Failed to connect to ${url}: ${error.message}`);
            reject(error);
        });
        
        // Set a timeout for connection
        setTimeout(() => {
            if (ws.readyState !== WebSocket.OPEN) {
                ws.terminate();
                reject(new Error(`Connection timeout to ${url}`));
            }
        }, 10000);
    });
}

function sendWebSocketMessage(ws, message, description) {
    return new Promise((resolve, reject) => {
        const timeout = setTimeout(() => {
            reject(new Error(`Timeout waiting for response from ${description}`));
        }, 10000);
        
        ws.once('message', (data) => {
            clearTimeout(timeout);
            const response = data.toString();
            logSuccess(`Response from ${description}: ${response}`);
            resolve(response);
        });
        
        ws.once('error', (error) => {
            clearTimeout(timeout);
            reject(error);
        });
        
        log(`Sending ${description}...`, 'cyan');
        ws.send(JSON.stringify(message));
    });
}

// Service management functions
function startSeller() {
    return new Promise((resolve, reject) => {
        log('Starting seller...', 'yellow');
        
        const args = [
            'run', '.',
            '--port=' + CONFIG.SELLER_P2P_PORT,
            '--mode=peer',
            '--buyer-or-seller=seller',
            '--envFile=.seller-env',
            '--use-local-address',
            '--ws-port=' + CONFIG.SELLER_WS_PORT
        ];
        
        sellerProcess = spawn('go', args, {
            stdio: ['ignore', 'pipe', 'pipe'],
            cwd: path.join(__dirname, '..')
        });
        
        sellerProcess.stdout.on('data', (data) => {
            const output = data.toString();
            if (output.includes('WebSocket server started') || output.includes('listening')) {
                logSuccess('Seller started successfully');
                resolve();
            }
        });
        
        sellerProcess.stderr.on('data', (data) => {
            const error = data.toString();
            if (error.includes('error') || error.includes('Error')) {
                logError(`Seller error: ${error}`);
            }
        });
        
        sellerProcess.on('error', (error) => {
            logError(`Failed to start seller: ${error.message}`);
            reject(error);
        });
        
        // Wait for service to be ready
        setTimeout(() => {
            if (sellerProcess && !sellerProcess.killed) {
                logSuccess('Seller process started');
                resolve();
            } else {
                reject(new Error('Seller failed to start'));
            }
        }, 5000);
    });
}

function startBuyer() {
    return new Promise((resolve, reject) => {
        log('Starting buyer...', 'yellow');
        
        const args = [
            'run', '.',
            '--port=' + CONFIG.BUYER_P2P_PORT,
            '--mode=peer',
            '--buyer-or-seller=buyer',
            '--list-of-sellers-source=env',
            '--envFile=.buyer-env',
            '--use-local-address',
            '--ws-port=' + CONFIG.BUYER_WS_PORT
        ];
        
        buyerProcess = spawn('go', args, {
            stdio: ['ignore', 'pipe', 'pipe'],
            cwd: path.join(__dirname, '..')
        });
        
        buyerProcess.stdout.on('data', (data) => {
            const output = data.toString();
            if (output.includes('WebSocket server started') || output.includes('listening')) {
                logSuccess('Buyer started successfully');
                resolve();
            }
        });
        
        buyerProcess.stderr.on('data', (data) => {
            const error = data.toString();
            if (error.includes('error') || error.includes('Error')) {
                logError(`Buyer error: ${error}`);
            }
        });
        
        buyerProcess.on('error', (error) => {
            logError(`Failed to start buyer: ${error.message}`);
            reject(error);
        });
        
        // Wait for service to be ready
        setTimeout(() => {
            if (buyerProcess && !buyerProcess.killed) {
                logSuccess('Buyer process started');
                resolve();
            } else {
                reject(new Error('Buyer failed to start'));
            }
        }, 5000);
    });
}

// Test functions
async function testSellerStatus() {
    log('Testing seller status...', 'cyan');
    
    const ws = await createWebSocket(`ws://localhost:${CONFIG.SELLER_WS_PORT}/seller/commands`);
    
    const statusMessage = {
        type: 'showCurrentPeers',
        data: '',
        timestamp: Date.now()
    };
    
    const response = await sendWebSocketMessage(ws, statusMessage, 'seller status check');
    ws.close();
    
    return response;
}

async function testBuyerStatus() {
    log('Testing buyer status...', 'cyan');
    
    const ws = await createWebSocket(`ws://localhost:${CONFIG.BUYER_WS_PORT}/buyer/commands`);
    
    const statusMessage = {
        type: 'showCurrentPeers',
        data: '',
        timestamp: Date.now()
    };
    
    const response = await sendWebSocketMessage(ws, statusMessage, 'buyer status check');
    ws.close();
    
    return response;
}

async function testP2PMessageFromSeller() {
    log('Testing P2P message from seller to buyer...', 'cyan');
    
    const ws = await createWebSocket(`ws://localhost:${CONFIG.SELLER_WS_PORT}/seller/p2p`);
    
    const p2pMessage = {
        type: 'p2p',
        data: CONFIG.TEST_MESSAGE,
        timestamp: Date.now(),
        publicKey: CONFIG.BUYER_PUBLIC_KEY
    };
    
    const response = await sendWebSocketMessage(ws, p2pMessage, 'P2P message from seller to buyer');
    ws.close();
    
    return response;
}

async function testP2PMessageFromBuyer() {
    log('Testing P2P message from buyer to seller...', 'cyan');
    
    const ws = await createWebSocket(`ws://localhost:${CONFIG.BUYER_WS_PORT}/buyer/p2p`);
    
    const p2pMessage = {
        type: 'p2p',
        data: CONFIG.RESPONSE_MESSAGE,
        timestamp: Date.now(),
        publicKey: CONFIG.SELLER_PUBLIC_KEY
    };
    
    const response = await sendWebSocketMessage(ws, p2pMessage, 'P2P message from buyer to seller');
    ws.close();
    
    return response;
}

// Main test function
async function runTests() {
    try {
        log('Starting comprehensive buyer-seller communication test', 'blue');
        log('==================================================', 'blue');
        
        // Step 1: Start seller
        await startSeller();
        await new Promise(resolve => setTimeout(resolve, 3000)); // Wait for seller to be ready
        
        // Step 2: Start buyer
        await startBuyer();
        await new Promise(resolve => setTimeout(resolve, 3000)); // Wait for buyer to be ready
        
        // Step 3: Wait for P2P connection to establish
        log('Waiting for P2P connection to establish...', 'yellow');
        await new Promise(resolve => setTimeout(resolve, 10000));
        
        // Step 4: Test seller status
        await testSellerStatus();
        
        // Step 5: Test buyer status
        await testBuyerStatus();
        
        // Step 6: Send P2P message from seller to buyer
        await testP2PMessageFromSeller();
        await new Promise(resolve => setTimeout(resolve, 3000)); // Wait for message processing
        
        // Step 7: Send P2P message from buyer to seller
        await testP2PMessageFromBuyer();
        await new Promise(resolve => setTimeout(resolve, 3000)); // Wait for message processing
        
        // Step 8: Final status checks
        log('Final status checks...', 'cyan');
        await testSellerStatus();
        await testBuyerStatus();
        
        log('==================================================', 'green');
        logSuccess('All tests completed successfully!');
        logSuccess('✓ Seller started and ready');
        logSuccess('✓ Buyer started and ready');
        logSuccess('✓ P2P messages sent successfully');
        logSuccess('✓ Status checks completed for both nodes');
        log('==================================================', 'green');
        
    } catch (error) {
        logError(`Test failed: ${error.message}`);
        process.exit(1);
    } finally {
        // Cleanup will be handled by the exit handler
        setTimeout(() => {
            process.exit(0);
        }, 2000);
    }
}

// Check if WebSocket module is available
try {
    require.resolve('ws');
} catch (e) {
    logError('WebSocket module not found. Please install it with: npm install ws');
    process.exit(1);
}

// Run the tests
runTests();
