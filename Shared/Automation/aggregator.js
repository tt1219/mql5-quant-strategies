const fs = require('fs');
const path = require('path');

const eaFolder = process.argv[2] || 'Rev_Bollinger';
console.log(`Aggregating results for Strategy Folder: ${eaFolder}`);

const resultsDir = path.join(__dirname, '..', '..', 'Experts', 'Strategies', eaFolder, 'BacktestResults_Opt');
const outputFile = path.join(__dirname, '..', '..', 'Experts', 'Strategies', eaFolder, 'reports', 'full_backtest_report.md');

if (!fs.existsSync(resultsDir)) {
    console.error(`Error: Results directory not found: ${resultsDir}`);
    process.exit(1);
}

const files = fs.readdirSync(resultsDir).filter(f => f.endsWith('.html'));
const allResults = [];

files.forEach(file => {
    try {
        const content = fs.readFileSync(path.join(resultsDir, file), 'utf16le');
        
        // Regex for filename parsing: OptReport_USDJPY_SHARP_M30_R2_D1.5_A25_Ph2_EMAtrue_A20_D1.4.html
        const regex = /OptReport_(.+?)_(.+?)_R([\d.]+)_D([\d.]+)_A(\d+)(.*)\.html/;
        const match = file.match(regex);
        if (!match) return;

        let symbol = match[1];
        let tf = match[2];
        let risk = match[3];
        let dev = match[4];
        let adx = match[5];
        let suffix = match[6]; // _Ph2_EMAtrue_A20_D1.4 etc

        // Override logic for Phase 2 optimization suffix
        if (suffix.includes('Ph2') || suffix.includes('EMA')) {
            const emaMatch = suffix.match(/EMA(true|false)/);
            const adxMatch = suffix.match(/_A(\d+)/);
            const devMatch = suffix.match(/_D([\d.]+)/);

            if (emaMatch) {
                const emaVal = (emaMatch[1] === 'true') ? 'EMA ON' : 'EMA OFF';
                suffix = emaVal; 
            }
            if (adxMatch) adx = adxMatch[1];
            if (devMatch) dev = devMatch[1];
        }

        // Extract Values from HTML
        const profitMatch = content.match(/(?:総損益:|Total net profit:).*?<b>\s*([-\d\s.,]+)\s*<\/b>/s);
        const profit = profitMatch ? parseFloat(profitMatch[1].replace(/[\s,]/g, '')) : 0.0;

        const pfMatch = content.match(/(?:プロフィットファクター:|Profit factor:).*?<b>\s*([-\d\s.]+)\s*<\/b>/s);
        const pf = pfMatch ? parseFloat(pfMatch[1].replace(/[\s,]/g, '')) : 0.0;

        const tradesMatch = content.match(/(?:取引数:|Total trades:).*?<b>\s*(\d+)\s*<\/b>/s);
        const trades = tradesMatch ? parseInt(tradesMatch[1], 10) : 0;

        const ddMatch = content.match(/(?:最大ドローダウン:|Maximal drawdown:).*?\(\s*([\d\s.,]+)%\s*\)/s);
        const drawdown = ddMatch ? parseFloat(ddMatch[1]) : 0.0;

        const tpm = (trades / 12).toFixed(1);

        // Benchmarking
        let status = '⚪';
        if (pf >= 1.7 && trades >= 40 && drawdown <= 10.0) status = '✅ PASS';
        else if (pf >= 1.5 && trades >= 30) status = '⚠️ WEAK';
        else status = '❌ FAIL';

        allResults.push({ symbol, tf, dev, adx, risk, profit, pf, trades, drawdown, tpm, status, suffix });
    } catch (e) {
        console.warn(`Warning: Failed to parse ${file}: ${e.message}`);
    }
});

allResults.sort((a, b) => b.profit - a.profit);

let output = [
    `# Backtest Report: ${eaFolder}`,
    `Generated on: ${new Date().toISOString().split('T')[0]}`,
    '',
    '| Status | Symbol | TF | Risk | Dev | ADX | EMA | Trades | TPM | Profit | PF | DD% |',
    '| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |'
];

allResults.forEach(r => {
    output.push(`| ${r.status} | ${r.symbol} | ${r.tf} | ${r.risk}% | ${r.dev} | ${r.adx} | ${r.suffix} | ${r.trades} | ${r.tpm} | ${r.profit.toFixed(2)} | ${r.pf.toFixed(2)} | ${r.drawdown.toFixed(2)}% |`);
});

if (!fs.existsSync(path.dirname(outputFile))) fs.mkdirSync(path.dirname(outputFile), { recursive: true });
fs.writeFileSync(outputFile, output.join('\n'), 'utf8');
console.log(`Success: Generated report for ${eaFolder} with ${allResults.length} entries.`);
