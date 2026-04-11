const fs = require('fs');
const path = require('path');

const eaName = process.argv[2] || 'BollingerHyper';
console.log(`Aggregating results for EA: ${eaName}`);

const resultsDir = path.join(__dirname, '..', '..', 'Experts', 'Active', eaName, 'BacktestResults_Opt');
const outputFile = path.join(__dirname, '..', '..', 'Experts', 'Active', eaName, 'reports', 'full_backtest_report.md');

const files = fs.readdirSync(resultsDir).filter(f => f.endsWith('.html'));
const allResults = [];

files.forEach(file => {
    try {
        // Read file as UTF-16LE (MT5 format)
        const content = fs.readFileSync(path.join(resultsDir, file), 'utf16le');
        
        // Parse filename: OptReport_SYMBOL(_SHARP)_TF_R2_D1.5_A25.html
        const parts = file.replace('.html', '').split('_');
        if (parts.length < 6) return;

        // 後ろから順に取得することで、Symbolに _SHARP が含まれるかどうかを柔軟に扱う
        const adx = parts[parts.length - 1].replace('A', '');
        const dev = parts[parts.length - 2].replace('D', '');
        // parts[parts.length - 3] is R2 (Skip)
        const tf = parts[parts.length - 4];
        
        // Symbol は OptReport_ と TF の間にあるすべてを結合して復元
        // (例: OptReport, EURUSD, SHARP, M15, R2...) -> EURUSD_SHARP
        const symbolParts = parts.slice(1, parts.length - 4);
        const symbol = symbolParts.join('_');

        // Use multiline regex to find values
        // Profit: Handles spaces in numbers
        const profitMatch = content.match(/(?:総損益:|Total net profit:).*?<b>\s*([-\d\s.,]+)\s*<\/b>/s);
        const profit = profitMatch ? parseFloat(profitMatch[1].replace(/[\s,]/g, '')) : 0.0;

        // PF
        const pfMatch = content.match(/(?:プロフィットファクター:|Profit factor:).*?<b>\s*([-\d\s.]+)\s*<\/b>/s);
        const pf = pfMatch ? parseFloat(pfMatch[1].replace(/[\s,]/g, '')) : 0.0;

        // Trades
        const tradesMatch = content.match(/(?:取引数:|Total trades:).*?<b>\s*(\d+)\s*<\/b>/s);
        const trades = tradesMatch ? parseInt(tradesMatch[1], 10) : 0;

        allResults.push({ symbol, tf, dev, adx, profit, pf, trades });
    } catch (e) {
        // Skip errors
    }
});

// Sort by Profit Descending
allResults.sort((a, b) => b.profit - a.profit);

// Format as Markdown Table
let output = [
    '| Symbol | TF | Dev | ADX | Trades | Net Profit (USD) | PF |',
    '| :--- | :--- | :--- | :--- | :--- | :--- | :--- |'
];

allResults.forEach(r => {
    output.push(`| ${r.symbol} | ${r.tf} | ${parseFloat(r.dev).toFixed(1)} | ${r.adx} | ${r.trades} | ${r.profit.toFixed(2)} | ${r.pf.toFixed(2)} |`);
});

fs.writeFileSync(outputFile, output.join('\n'), 'utf8');
console.log(`Success: Generated report with ${allResults.length} entries.`);
