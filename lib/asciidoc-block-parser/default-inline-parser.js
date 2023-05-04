'use strict'

const { splitLines } = require('#util')

module.exports = {
  parse (value, { locations } = {}) {
    let start, end
    const lines = splitLines(value)
    const endLine = lines.length
    const endCol = lines[endLine - 1].length
    if (locations) {
      start = locations[1]
      ;(end = Object.assign({}, locations[endLine])).col += endCol - 1
    } else {
      start = { line: 1, col: 1 }
      end = { line: endLine, col: endCol }
    }
    return [{ name: 'text', type: 'string', value, location: [start, end] }]
  },
}
