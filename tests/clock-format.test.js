const assert = require('node:assert/strict');
const fs = require('node:fs');

const source = fs.readFileSync('Components/Clock.qml', 'utf8');
assert.match(source, /function formatAmPmTime\(date\)/, 'Clock.qml must define manual AM/PM formatter');
assert.match(source, /format === "h:mm AP"/, 'h:mm AP must bypass localized AM/PM suffixes');

const bodyMatch = source.match(/function formatAmPmTime\(date\) \{([\s\S]*?)\n        \}/);
assert.ok(bodyMatch, 'formatAmPmTime body must be extractable');
const formatAmPmTime = new Function('date', `${bodyMatch[1]}\n`);

assert.equal(formatAmPmTime(new Date(2026, 0, 1, 0, 5)), '12:05 AM');
assert.equal(formatAmPmTime(new Date(2026, 0, 1, 9, 30)), '9:30 AM');
assert.equal(formatAmPmTime(new Date(2026, 0, 1, 12, 0)), '12:00 PM');
assert.equal(formatAmPmTime(new Date(2026, 0, 1, 23, 59)), '11:59 PM');
