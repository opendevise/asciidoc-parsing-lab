'use strict'

// TODO use own implementation w/ cache like built-in impl
// TODO need to take into account that lines may come from different files
function computeLocation (delegate, locations, range) {
  const { start: startOffset, end: endOffset } = range
  // NOTE endOffset is always the character offset one beyond what was consumed
  const {
    start: { line: startLine, column: startCol },
    end: { line: endLine, column: endCol },
  } = delegate(startOffset, endOffset - 1)
  if (!locations) return [{ line: startLine, col: startCol }, { line: endLine, col: endCol }]
  const start = Object.assign({}, locations[startLine])
  start.col += startCol - 1
  const end = Object.assign({}, locations[endLine])
  end.col += endCol - 1
  return [start, end]
}

function transformToModel (nodes, rangeToLocation, startOffset = 0) {
  //return nodes
  let currentTextNode
  return nodes.reduce((accum, node) => {
    let next
    if (Array.isArray(node)) [node, next] = node
    while (true) {
      if (node.constructor === String) {
        let sourceLength = node.sourceLength
        if (sourceLength == null) {
          sourceLength = node.length
        } else {
          node = String(node)
        }
        if (currentTextNode) {
          const endOffset = (currentTextNode.endOffset += sourceLength)
          currentTextNode.value += node
          currentTextNode.location = rangeToLocation({ start: startOffset, end: endOffset })
        } else {
          const endOffset = startOffset + sourceLength
          const offsetRange = { start: startOffset, end: endOffset }
          currentTextNode = { name: 'text', type: 'string', value: node, location: rangeToLocation(offsetRange) }
          Object.defineProperty(currentTextNode, 'endOffset', { enumerable: false, writable: true, value: endOffset })
          accum.push(currentTextNode)
        }
        if (next) {
          node = next
          next = undefined
          continue
        }
        return accum
      } else {
        node.location = rangeToLocation(node.range)
        if (node.inlines?.length) {
          node.inlines = transformToModel(node.inlines, rangeToLocation, node.range.inlinesStart)
        }
        startOffset = node.range.end
        delete node.range
      }
      currentTextNode = undefined
      accum.push(node)
      return accum
    }
  }, [])
}

function unshiftOntoCopy (arr, it) {
  const accum = [it]
  for (let i = 0, len = arr.length; i < len; i++) accum.push(arr[i])
  return accum
}

module.exports = { computeLocation, transformToModel, unshiftOntoCopy }
