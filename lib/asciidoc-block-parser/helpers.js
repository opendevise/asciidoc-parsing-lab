'use strict'

function createContext () {
  return { sectionStack: [], containerStack: [], listStack: [] }
}

function enterBlock (context, delimiter) {
  if (isBlockEnd(context, delimiter)) return false
  const { containerStack, listStack } = context
  containerStack.push({ delimiter, listStack })
  context.listStack = []
  return true
}

function exitBlock (context) {
  const { containerStack } = context
  const { listStack: previousListStack, delimiter } = containerStack.pop()
  context.listStack = previousListStack
  return delimiter
}

function exitList (context) {
  return context.listStack.pop()
}

function exitSection (context) {
  context.sectionStack.pop()
}

function isBlockEnd ({ containerStack }, delimiter) {
  return containerStack.length && delimiter === containerStack[containerStack.length - 1].delimiter
}

function isCurrentList ({ listStack }, marker) {
  if (marker[marker.length - 1] === '.' && marker !== '.') marker = '1.'
  return marker === listStack[listStack.length - 1]
}

function isNestedSection ({ sectionStack }, level) {
  if (!sectionStack.length || level > sectionStack[sectionStack.length - 1]) {
    sectionStack.push(level)
    return true
  }
  return false
}

function isNewList ({ listStack }, marker) {
  if (marker[marker.length - 1] === '.' && marker !== '.') marker = '1.'
  if (listStack.length && ~listStack.indexOf(marker)) return false
  listStack.push(marker)
  return true
}

function toInlines (name, value, location) {
  return [{ type: 'string', name, value, location }]
}

module.exports = {
  createContext,
  enterBlock,
  exitBlock,
  exitList,
  exitSection,
  isBlockEnd,
  isCurrentList,
  isNestedSection,
  isNewList,
  toInlines,
}
