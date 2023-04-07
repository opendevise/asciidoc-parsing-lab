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
        if (currentTextNode) {
          const endOffset = (currentTextNode.endOffset += (node.escaped ? 2 : node.length))
          currentTextNode.value += node
          currentTextNode.location = rangeToLocation({ start: startOffset, end: endOffset })
        } else {
          let endOffset
          if (node.escaped) {
            endOffset = (startOffset += 1) + 1
            node = String(node)
          } else {
            endOffset = startOffset + node.length
          }
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
