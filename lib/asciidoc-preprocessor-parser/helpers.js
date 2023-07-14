'use strict'

const { unshiftOntoCopy } = require('#util')

function evaluateIf (operands, catalog) {
  const logicOperatorAndNames = operands[1]
  if (!logicOperatorAndNames) return operands[0] in catalog
  const names = unshiftOntoCopy(logicOperatorAndNames[1], operands[0])
  return names[logicOperatorAndNames[0] === ',' ? 'some' : 'every']((name) => name in catalog)
}

module.exports = { evaluateIf }
