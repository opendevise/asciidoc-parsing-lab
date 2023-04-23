'use strict'

// TODO use own implementation w/ cache like built-in impl
// TODO need to take into account that lines may come from different files
function computeLocation (delegate, lineOffset, columnOffset, { start: startOffset, end: endOffset }) {
  const {
    start: { line: startLine, column: startColumn },
    end: { line: endLine, column: endColumn },
  } = delegate(startOffset, endOffset)
  return {
    start: {
      line: startLine + lineOffset,
      column: startColumn + columnOffset,
    },
    end: {
      line: endLine + lineOffset,
      column: columnOffset && startLine === endLine ? endColumn + columnOffset : ((endColumn - 1) || 1),
    },
  }
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
