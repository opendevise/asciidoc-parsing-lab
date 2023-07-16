'use strict'

const { unshiftOntoCopy } = require('#util')

function evaluateIf (operands, catalog) {
  const logicOperatorAndNames = operands[1]
  if (!logicOperatorAndNames) return catalog[operands[0]]?.value != null
  const names = unshiftOntoCopy(logicOperatorAndNames[1], operands[0])
  return names[logicOperatorAndNames[0] === ',' ? 'some' : 'every']((name) => catalog[name]?.value != null)
}

module.exports = { evaluateIf }
