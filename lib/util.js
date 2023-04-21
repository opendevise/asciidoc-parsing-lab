'use strict'

function splitLines (str) {
  return str.split('\n').reduce((accum, line, idx) => {
    if (idx) accum[idx - 1] += '\n'
    accum.push(line)
    return accum
  }, [])
}

module.exports = { splitLines }
