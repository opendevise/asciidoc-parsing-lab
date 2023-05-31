'use strict'

function computeLocation (sourceMapping, offsetToSourceLocation, range) {
  let { start: startOffset, end: after, endOffset = after - 1 } = range // endOffset always one beyond what was consumed
  if (sourceMapping) {
    if (Array.isArray((startOffset = sourceMapping[startOffset].offset))) startOffset = startOffset[0]
    if (Array.isArray((endOffset = sourceMapping[endOffset].offset))) endOffset = endOffset[1]
  }
  return [offsetToSourceLocation[startOffset], offsetToSourceLocation[endOffset]]
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

module.exports = { computeLocation, transformToModel }
