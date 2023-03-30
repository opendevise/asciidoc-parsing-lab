'use strict'

module.exports = {
  parse (value, { startLine = 1, startColumn = 1 } = {}) {
    const lines = value.split('\n')
    const endLine = startLine + lines.length - 1
    let endColumn = lines[lines.length - 1].length
    if (startColumn > 1 && startLine === endLine) endColumn += (startColumn - 1)
    return [{
      name: 'text',
      type: 'string',
      value,
      location: { start: { line: startLine, column: startColumn }, end: { line: endLine, column: endColumn } },
    }]
  },
}
