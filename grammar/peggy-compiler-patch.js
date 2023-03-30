'use strict'

function rewriteRegExps (node) {
  const children = node.children
  for (const [idx, child] of children.entries()) {
    if (typeof child === 'string') {
      if (child.includes('var peg$r') && child.includes('p{')) {
        children[idx] = child.replace(/^( *var peg\$r\d+ .*? )(\/.*p\{.+?\}.*\/)(;.*)/gm, (match, before, rx, after) => {
          return before + rx.replace(/(?!<\\)p\{.+?\}/g, '\\$&') + 'u' + after
        })
        break
      }
    } else {
      rewriteRegExps(child)
    }
  }
}

module.exports = {
  use (config, options) {
    config.passes.generate.push((ast) => {
      // rewrite mangled regexp that contains unicode properties (e.g., p{Alpha})
      rewriteRegExps(ast.code)
    })
  }
}
