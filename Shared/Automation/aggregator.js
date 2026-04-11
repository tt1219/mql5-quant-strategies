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
        
        const parts = file.replace('.html', '').split('_');
        if (parts.length < 5) return;

        // Parse Params from Filename
        const adx = parts[parts.length - 1].replace('A', '');
        const dev = parts[parts.length - 2].replace('D', '');
        const risk = parts[parts.length - 3].replace('R', '');
        const tf = parts[parts.length - 4];
        const symbolParts = parts.slice(1, parts.length - 4);
        const symbol = symbolParts.join('_');

        // Extract Values from HTML
        const profitMatch = content.match(/(?:総損益:|Total net profit:).*?<b>\s*([-\d\s.,]+)\s*<\/b>/s);
        const profit = profitMatch ? parseFloat(profitMatch[1].replace(/[\s,]/g, '')) : 0.0;

        const pfMatch = content.match(/(?:プロフィットファクター:|Profit factor:).*?<b>\s*([-\d\s.]+)\s*<\/b>/s);
        const pf = pfMatch ? parseFloat(pfMatch[1].replace(/[\s,]/g, '')) : 0.0;

        const tradesMatch = content.match(/(?:取引数:|Total trades:).*?<b>\s*(\d+)\s*<\/b>/s);
        const trades = tradesMatch ? parseInt(tradesMatch[1], 10) : 0;

        // Drawdown %
        const ddMatch = content.match(/(?:最大ドローダウン:|Maximal drawdown:).*?\(\s*([\d\s.,]+)%\s*\)/s);
        const drawdown = ddMatch ? parseFloat(ddMatch[1]) : 0.0;

        // Calculation: Trades per month (Assume roughly 12 months for now)
        const tpm = (trades / 12).toFixed(1);

        allResults.push({ symbol, tf, dev, adx, risk, profit, pf, trades, drawdown, tpm });
    } catch (e) {
        console.warn(`Warning: Failed to parse ${file}: ${e.message}`);
    }
});

allResults.sort((a, b) => b.profit - a.profit);

let output = [
    '| Symbol | TF | Risk | Dev | ADX | Trades | TPM | Profit | PF | DD% |',
    '| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |'
];

allResults.forEach(r => {
    output.push(`| ${r.symbol} | ${r.tf} | ${r.risk}% | ${parseFloat(r.dev).toFixed(1)} | ${r.adx} | ${r.trades} | ${r.tpm} | ${r.profit.toFixed(2)} | ${r.pf.toFixed(2)} | ${r.drawdown.toFixed(2)}% |`);
});

if (!fs.existsSync(path.dirname(outputFile))) fs.mkdirSync(path.dirname(outputFile), { recursive: true });
fs.writeFileSync(outputFile, output.join('\n'), 'utf8');
console.log(`Success: Generated report for ${eaFolder} with ${allResults.length} entries.`);
