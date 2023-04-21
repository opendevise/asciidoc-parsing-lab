{{
const fs = require('node:fs')
const { splitLines } = require('#util')
}}
{
options.attributes = {}
options.offsets = Object.assign({}, { delta: 0 })
}
document = body lf*
  {
    const offsets = options.offsets
    const delta = offsets.delta
    const end = location().end
    let lastLine = !end.offset || input[input.length - 1] === '\n' ? end.line - 1 : end.line
    for (let n = lastLine; n > 0; n--) {
      if (n in offsets) break
      offsets[n] = { line: n + delta, column: 1, delta }
    }
    let n = lastLine + 1
    while (n in offsets) delete offsets[n++]
    delete offsets.delta
    return { input, offsets }
  }

body = block*

block = (pp (lf / attribute_entry))* @(example / listing / list / paragraph)

example = '====\n' contents:paragraph pp '====' eol
  {
    return { name: 'example', contents, location: location() }
  }

listing = '----\n' contents:$(pp !('----' eol) [^\n]+ eol / '\n')* pp '----' eol
  {
    return { name: 'listing', contents, location: location() }
  }

// TODO don't need to check pp on first line
paragraph = contents:(pp !('====' eol / list_start) @line)+
  {
    return { name: 'paragraph', contents, location: location() }
  }

list = items:(pp @list_item)+
  {
    return { name: 'list', items, location: location() }
  }

list_start = list_marker !eol

list_marker = '* '

list_item = list_start principal:$([^\n]+ eol (pp !('+\n' / list_start / '====' eol) [^\n]+ eol)*) blocks:attached_block*
  {
    return { name: 'listItem', principal, blocks, location: location() }
  }

attached_block = pp '+\n' @(example / paragraph)

attribute_entry = ':' name:attribute_name ':' value:(' ' @$[^\n]+ / '') eol
  {
    options.attributes[name] = value
  }

line = value:$([^\n]+ eol)
  {
    return { value, location: location() }
  }

conditional_lines = lines:(!('endif::[]' eol) @(pp_conditional_pair / $([^\n]+ eol) / '\n'))*
  {
    return lines.flat()
  }

pp_conditional_pair = opening:$(('ifdef' / 'ifndef') '::' attribute_name '[]\n') contents:conditional_lines closing:$('endif::[]' eol)?
  {
    if (closing) contents.push(closing)
    return [opening, ...contents]
  }

//pp = (pp_directive* &{ return false })?
pp = (pp_directive* . !.)?
// Q: is there a cleaner way to fail pp_directive to restore currPos, but still keep checking??
//pp = ((modified:(&{ return true } { return {} }) (pp_directive &{ return !(modified.true = true) } / &{ return modified.true }))* . !.)?

pp_directive = &('if' / 'inc') @(pp_conditional_short / pp_conditional / pp_include)

pp_include = 'include::' target:$[^\[\n]+ '[]' eol
  {
    const { start: { offset: startOffset, line: startLine }, end: { offset: endOffset, line: endLine } } = location()
    const offsets = options.offsets
    const delta = offsets.delta
    if (!offsets[startLine - 1]) {
      for (let n = startLine - 1; n > 0; n--) {
        if (n in offsets) break
        offsets[n] = { line: n + delta, column: 1, delta }
      }
    }
    const contents = splitLines(fs.readFileSync(target, 'utf8'))
    const contentsLastLine = contents.pop()
    contents.push(contentsLastLine[contentsLastLine.length - 1] === '\n' ? contentsLastLine : contentsLastLine + '\n')
    // TODO deal with case when no lines are added
    const numAdded = contents.length
    let n = endLine
    while (n in offsets) offsets[n + numAdded] = offsets[n++]
    const parent = offsets[startLine].file || '<input>'
    for (let l = 0, len = numAdded; l < len; l++) {
      offsets[l + startLine] = { line: l + 1, column: 1, delta: 0, file: target, parent }
    }
    offsets.delta -= (numAdded - 1)
    input = input.slice(0, (peg$currPos = startOffset)) + contents.join('') + input.slice(endOffset)
    // NOTE might be able to avoid this if we don't rely on location()
    peg$posDetailsCache = [{ line: 1, column: 1 }]
    return true
  }

pp_conditional_short = operator:('ifdef' / 'ifndef') '::' attribute_name:attribute_name '[' mark:grab_offset contents:$([^\n\]]+ &(']' eol) / ([^\n\]] / ']' !eol)+) ']' eol:eol
  {
    const { start: { offset: startOffset, line: startLine }, end: { offset: endOffset, line: endLine } } = location()
    const offsets = options.offsets
    const delta = offsets.delta
    for (let n = startLine; n > 0; n--) {
      if (n in offsets) break
      offsets[n] = { line: n + delta, column: 1, delta }
    }
    const drop = operator === 'ifdef' ? !(attribute_name in options.attributes) : (attribute_name in options.attributes)
    if (drop) {
      if (eol) {
        let n = endLine
        if (!offsets[n]) offsets[n] = { line: n + delta, column: 1, delta }
        while (n in offsets) {
          offsets[n].delta += 1
          offsets[n - 1] = offsets[n]
          delete offsets[n++]
        }
      } else {
        delete offsets[startLine]
      }
    } else {
      offsets[startLine].column = mark - startOffset + 1
    }
    input = input.slice(0, (peg$currPos = startOffset)) + (drop ? '' : contents + (eol || '')) + input.slice(endOffset)
    peg$posDetailsCache = [{ line: 1, column: 1 }]
    return true
  }

// TODO always succeed even if endif::[] is missing
// Q could the positive case only process the opening directive and process the closing directive separately? the negative case would still have to consume lines, so this might require the use of a semantic predicate
pp_conditional = operator:('ifdef' / 'ifndef') '::' attribute_name:attribute_name '[]\n' contents:conditional_lines 'endif::[]' eol:eol
  {
    const { start: { offset: startOffset, line: startLine }, end: { offset: endOffset, line: endLine } } = location()
    const newEndLine = endLine - 2
    const offsets = options.offsets
    const delta = offsets.delta
    // Q: better to do this in the document action?
    if (!offsets[startLine - 1]) {
      for (let n = startLine - 1; n > 0; n--) {
        if (n in offsets) break
        offsets[n] = { line: n + delta, column: 1, delta }
      }
    }
    const drop = operator === 'ifdef' ? !(attribute_name in options.attributes) : (attribute_name in options.attributes)
    if (drop) {
      const numDropped = contents.length + 2
      let l = endLine
      if (!offsets[l]) offsets[l] = { line: l + delta, column: 1, delta }
      while (l in offsets) offsets[l++].delta += numDropped
      for (let n = startLine; n < endLine; n++) delete offsets[n]
      let n = endLine
      while (n in offsets) {
        offsets[n - numDropped] = offsets[n]
        delete offsets[n++]
      }
      offsets.delta = offsets[n - 1 - numDropped].delta
    } else {
      if (!offsets[startLine]) {
        for (let l = startLine; l < endLine; l++) offsets[l] = { line: l + delta, column: 1, delta }
      }
      let l = startLine
      const currentInclude = offsets[startLine].file
      let closingLine = eol ? endLine - 1 : endLine
      let newDelta = delta + 2
      while (l in offsets) {
        // FIXME only move delta if in same file
        if (l > startLine && offsets[l].file === currentInclude) {
          l > closingLine ? (newDelta = offsets[l].delta += 2) : (offsets[l].delta += 1)
        }
        if (l !== startLine && l !== closingLine) offsets[l - (l > closingLine ? 2 : 1)] = offsets[l]
        delete offsets[l++]
      }
      // NOTE if included lines are reduced then root delta increases
      currentInclude ? (offsets.delta += 2) : (offsets.delta = newDelta)
    }
    input = input.slice(0, (peg$currPos = startOffset)) + (drop ? '' : contents.join('')) + input.slice(endOffset)
    peg$posDetailsCache = [{ line: 1, column: 1 }]
    return true
  }

attribute_name = $[a-z]+

grab_offset = ''
  {
    return offset()
  }

lf = '\n'

eof = !.

eol = '\n' / eof
