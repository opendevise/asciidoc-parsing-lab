'use strict'

module.exports = {
  parse (value, { startLine = 1, startCol = 1 } = {}) {
    const lines = value.split('\n')
    const endLine = startLine + lines.length - 1
    let endCol = lines[lines.length - 1].length
    if (startCol > 1 && startLine === endLine) endCol += (startCol - 1)
    return [{
      name: 'text',
      type: 'string',
      value,
      location: [{ line: startLine, col: startCol }, { line: endLine, col: endCol }],
    }]
  },
}
