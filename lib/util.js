'use strict'

function splitLines (str) {
  return str.split('\n').reduce((accum, line, idx) => {
    if (idx) accum[idx - 1] += '\n'
    accum.push(line)
    return accum
  }, [])
}

function unshiftOntoCopy (arr, it) {
  const accum = [it]
  for (let i = 0, len = arr.length; i < len; i++) accum.push(arr[i])
  return accum
}

module.exports = { splitLines, unshiftOntoCopy }
