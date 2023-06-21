/* eslint-env mocha */
'use strict'

const { expect } = require('#test-harness')
const { parse } = require('#inline-parser')
const inlinePreprocessor = require('#inline-preprocessor')

describe('inline (unported)', () => {
  const loc = (start, end = start) => {
    let startLine, startCol, endLine, endCol
    if (Array.isArray(start)) {
      ;([startLine, startCol] = start)
    } else {
      startLine = 1
      startCol = start
    }
    if (Array.isArray(end)) {
      ;([endLine, endCol] = end)
    } else {
      endLine = startLine
      endCol = typeof end === 'string' ? end.length : end
    }
    return [{ line: startLine, col: startCol }, { line: endLine, col: endCol }]
  }

  describe('no markup', () => {
    it('empty', () => {
      const input = ''
      const expected = []
      expect(parse(input)).to.eql(expected)
    })

    it('single word with no markup', () => {
      const input = 'hello'
      const expected = [{ type: 'string', name: 'text', value: input, location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('colon character at end of line', () => {
      const input = 'practices include:'
      const expected = [{ type: 'string', name: 'text', value: input, location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('multiple words with no markup', () => {
      const input = 'hello, world!'
      const expected = [{ type: 'string', name: 'text', value: input, location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('multiple lines with no markup', () => {
      const input = 'hello, world!\n¡adiós!'
      const expected = [{ type: 'string', name: 'text', value: input, location: loc(1, [2, 7]) }]
      expect(parse(input)).to.eql(expected)
    })
  })

  describe('escaped markup', () => {
    it('escaped backslash', () => {
      const input = '\\\\'
      const expected = [{ type: 'string', name: 'text', value: '\\', location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('escaped lone formatting mark', () => {
      const marks = ['`', '_', '*', '#']
      marks.forEach((mark) => {
        const input = '\\' + mark
        const expected = [{ type: 'string', name: 'text', value: mark, location: loc(1, input) }]
        expect(parse(input)).to.eql(expected)
      })
    })

    it('escaped formatting mark followed by wordy', () => {
      const marks = ['`', '_', '*', '#']
      marks.forEach((mark) => {
        const input = '\\' + mark + 'disclaimer'
        const expected = [{ type: 'string', name: 'text', value: mark + 'disclaimer', location: loc(1, input) }]
        expect(parse(input)).to.eql(expected)
      })
    })

    it('constrained strong preceded by escaped backslash', () => {
      const input = '\\\\*seeing stars*'
      const expected = [
        { type: 'string', name: 'text', value: '\\', location: loc(1, 2) },
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(3, 16),
          inlines: [{ type: 'string', name: 'text', value: 'seeing stars', location: loc(4, 15) }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('escaped opening constrained strong mark', () => {
      const input = '\\*seeing stars*'
      const expected = [{ type: 'string', name: 'text', value: '*seeing stars*', location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('escaped opening constrained strong mark preceded by escaped backslash', () => {
      const input = '\\\\\\*seeing stars*'
      const expected = [{ type: 'string', name: 'text', value: '\\*seeing stars*', location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('escaped closing constrained strong mark', () => {
      const input = '*seeing stars\\*'
      const expected = [{ type: 'string', name: 'text', value: '*seeing stars*', location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('escaped constrained strong adjacent to word', () => {
      const input = 'seeing\\*stars*'
      const expected = [{ type: 'string', name: 'text', value: 'seeing*stars*', location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('escaped opening unconstrained strong mark', () => {
      const input = '\\*\\*seeing stars**'
      const expected = [{ type: 'string', name: 'text', value: '**seeing stars**', location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('escaped closing unconstrained strong mark', () => {
      const input = '**seeing stars\\*\\*'
      const expected = [{ type: 'string', name: 'text', value: '**seeing stars**', location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong enclosed in escaped unconstrained strong', () => {
      const input = '\\**enclosed in stars**'
      const expected = [
        { type: 'string', name: 'text', value: '*', location: loc(1, 2) },
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(3, 21),
          inlines: [{ type: 'string', name: 'text', value: 'enclosed in stars', location: loc(4, 20) }],
        },
        { type: 'string', name: 'text', value: '*', location: loc(input.length) },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('escaped xref shorthand notation', () => {
      const input = '\\<<foo>>'
      const expected = [{ type: 'string', name: 'text', value: '<<foo>>', location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('escaped lone less than sign', () => {
      const input = '\\<'
      const expected = [{ type: 'string', name: 'text', value: '<', location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })
  })

  // TODO group under marked text
  describe('uninterpreted markup (marked text)', () => {
    it('lone constrained strong mark', () => {
      const input = '*'
      const expected = [{ type: 'string', name: 'text', value: input, location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('lone unconstrained strong mark', () => {
      const input = '**'
      const expected = [{ type: 'string', name: 'text', value: input, location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('unpaired constrained strong mark at end of line', () => {
      const input = 'certain conditions apply*'
      const expected = [{ type: 'string', name: 'text', value: input, location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong preceded by ASCII word character', () => {
      const input = 'foo*bar*'
      const expected = [{ type: 'string', name: 'text', value: input, location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong preceded by ASCII word character following space', () => {
      const input = ' foo*bar*'
      const expected = [{ type: 'string', name: 'text', value: input, location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong preceded by non-ASCII word character', () => {
      const input = 'žádný*strong*'
      const expected = [{ type: 'string', name: 'text', value: input, location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong followed by ASCII word character', () => {
      const input = '*foo*bar'
      const expected = [{ type: 'string', name: 'text', value: input, location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong followed by non-ASCII word character', () => {
      const input = '*strong*žádný'
      const expected = [{ type: 'string', name: 'text', value: input, location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong marks around space', () => {
      const input = '* *'
      const expected = [{ type: 'string', name: 'text', value: input, location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong marks around multiple spaces', () => {
      const input = '*  *'
      const expected = [{ type: 'string', name: 'text', value: input, location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong marks around word offset by spaces', () => {
      const input = '* foo *'
      const expected = [{ type: 'string', name: 'text', value: input, location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('opening constrained strong mark followed by space', () => {
      const input = '* foo*'
      const expected = [{ type: 'string', name: 'text', value: input, location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })

    it('closing constrained strong mark preceded by space', () => {
      const input = '*foo *'
      const expected = [{ type: 'string', name: 'text', value: input, location: loc(1, input) }]
      expect(parse(input)).to.eql(expected)
    })
  })

  describe('constrained strong', () => {
    it('single non-space character in constrained strong', () => {
      const input = '*s*'
      const expected = [{
        type: 'inline',
        name: 'span',
        variant: 'strong',
        form: 'constrained',
        location: loc(1, 3),
        inlines: [{ type: 'string', name: 'text', value: 's', location: loc(2) }],
      }]
      expect(parse(input)).to.eql(expected)
    })

    it('single word in constrained strong', () => {
      const input = '*strong*'
      const expected = [{
        type: 'inline',
        name: 'span',
        variant: 'strong',
        form: 'constrained',
        location: loc(1, input),
        inlines: [{ type: 'string', name: 'text', value: 'strong', location: loc(2, input.length - 1) }],
      }]
      expect(parse(input)).to.eql(expected)
    })

    it('multiple words in constrained strong', () => {
      const input = '*foo bar*'
      const expected = [{
        type: 'inline',
        name: 'span',
        variant: 'strong',
        form: 'constrained',
        location: loc(1, input),
        inlines: [{ type: 'string', name: 'text', value: 'foo bar', location: loc(2, input.length - 1) }],
      }]
      expect(parse(input)).to.eql(expected)
    })

    it('single asterisk in constrained strong', () => {
      const input = '***'
      const expected = [{
        type: 'inline',
        name: 'span',
        variant: 'strong',
        form: 'constrained',
        location: loc(1, input),
        inlines: [{ type: 'string', name: 'text', value: '*', location: loc(input.length - 1) }],
      }]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong preceded by text offset by space', () => {
      const input = 'before *strong*'
      const expected = [
        { type: 'string', name: 'text', value: 'before ', location: loc(1, 7) },
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(8, input),
          inlines: [{ type: 'string', name: 'text', value: 'strong', location: loc(9, input.length - 1) }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong followed by text offset by space', () => {
      const input = '*strong* after'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(1, 8),
          inlines: [{ type: 'string', name: 'text', value: 'strong', location: loc(2, 7) }],
        },
        { type: 'string', name: 'text', value: ' after', location: loc(9, input) },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong in between text offset by space', () => {
      const input = 'it *does not* mean certain victory'
      const expected = [
        { type: 'string', name: 'text', value: 'it ', location: loc(1, 3) },
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(4, 13),
          inlines: [{ type: 'string', name: 'text', value: 'does not', location: loc(5, 12) }],
        },
        { type: 'string', name: 'text', value: ' mean certain victory', location: loc(14, input) },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong containing constrained strong mark in middle of word', () => {
      const input = '*str*ong*'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(1, input),
          inlines: [{ type: 'string', name: 'text', value: 'str*ong', location: loc(2, input.length - 1) }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    // NOTE Asciidoctor gets this one wrong
    it('two adjacent strong constrained words', () => {
      const input = '*foo**bar*'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(1, 5),
          inlines: [{ type: 'string', name: 'text', value: 'foo', location: loc(2, 4) }],
        },
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(6, input),
          inlines: [{ type: 'string', name: 'text', value: 'bar', location: loc(7, input.length - 1) }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong adjacent to constrained emphasis', () => {
      const input = '_foo_*bar*'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'emphasis',
          form: 'constrained',
          location: loc(1, 5),
          inlines: [{ type: 'string', name: 'text', value: 'foo', location: loc(2, 4) }],
        },
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(6, input),
          inlines: [{ type: 'string', name: 'text', value: 'bar', location: loc(7, input.length - 1) }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    // NOTE this differs from the behavior of Asciidoctor, but Asciidoctor gets this one wrong
    it('constrained strong mark between strong constrained words', () => {
      const input = '*foo***bar*'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(1, 5),
          inlines: [{ type: 'string', name: 'text', value: 'foo', location: loc(2, 4) }],
        },
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(6, input),
          inlines: [{ type: 'string', name: 'text', value: '*bar', location: loc(7, input.length - 1) }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong containing constrained strong mark offset by spaces', () => {
      const input = '*foo * bar*'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(1, input),
          inlines: [{ type: 'string', name: 'text', value: 'foo * bar', location: loc(2, input.length - 1) }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong containing unconstrained strong mark offset by spaces', () => {
      const input = '*foo ** bar*'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(1, 7),
          inlines: [{ type: 'string', name: 'text', value: 'foo *', location: loc(2, 6) }],
        },
        { type: 'string', name: 'text', value: ' bar*', location: loc(8, input) },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong preceded by unmatched opening unconstrained strong mark at start of line', () => {
      const input = '**strong*'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(1, input),
          inlines: [{ type: 'string', name: 'text', value: '*strong', location: loc(2, input.length - 1) }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong preceded by unmatched opening unconstrained strong mark preceded by space', () => {
      const input = 'before **strong*'
      const expected = [
        { type: 'string', name: 'text', value: 'before ', location: loc(1, 7) },
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(8, input),
          inlines: [{ type: 'string', name: 'text', value: '*strong', location: loc(9, input.length - 1) }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong preceded by unmatched opening unconstrained strong mark preceded by word character', () => {
      const input = 'before**strong*'
      const expected = [
        { type: 'string', name: 'text', value: 'before*', location: loc(1, 7) },
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(8, input),
          inlines: [{ type: 'string', name: 'text', value: 'strong', location: loc(9, input.length - 1) }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong containing constrained strong mark preceded by space', () => {
      const input = '*foo **'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(1, input),
          inlines: [{ type: 'string', name: 'text', value: 'foo *', location: loc(2, input.length - 1) }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong containing constrained strong mark followed by space', () => {
      const input = '** foo*'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(1, input),
          inlines: [{ type: 'string', name: 'text', value: '* foo', location: loc(2, input.length - 1) }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong containing uninterpreted constrained emphasis marks', () => {
      const input = '*fo*o_bar_*'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(1, input),
          inlines: [{ type: 'string', name: 'text', value: 'fo*o_bar_', location: loc(2, input.length - 1) }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })
  })

  describe('unconstrained strong', () => {
    it('single letter in unconstrained strong', () => {
      const input = '**s**'
      const expected = [{
        type: 'inline',
        name: 'span',
        variant: 'strong',
        form: 'unconstrained',
        location: loc(1, input),
        inlines: [{ type: 'string', name: 'text', value: 's', location: loc(3, input.length - 2) }],
      }]
      expect(parse(input)).to.eql(expected)
    })

    it('single word in unconstrained strong', () => {
      const input = '**strong**'
      const expected = [{
        type: 'inline',
        name: 'span',
        variant: 'strong',
        form: 'unconstrained',
        location: loc(1, input),
        inlines: [{ type: 'string', name: 'text', value: 'strong', location: loc(3, input.length - 2) }],
      }]
      expect(parse(input)).to.eql(expected)
    })

    it('multiple words in unconstrained strong', () => {
      const input = '**definitely strong**'
      const expected = [{
        type: 'inline',
        name: 'span',
        variant: 'strong',
        form: 'unconstrained',
        location: loc(1, input),
        inlines: [{ type: 'string', name: 'text', value: 'definitely strong', location: loc(3, input.length - 2) }],
      }]
      expect(parse(input)).to.eql(expected)
    })

    it('word bounded by spaces in unconstrained strong', () => {
      const input = '** still strong **'
      const expected = [{
        type: 'inline',
        name: 'span',
        variant: 'strong',
        form: 'unconstrained',
        location: loc(1, input),
        inlines: [{ type: 'string', name: 'text', value: ' still strong ', location: loc(3, input.length - 2) }],
      }]
      expect(parse(input)).to.eql(expected)
    })

    it('unconstrained strong following word offset by space', () => {
      const input = 'before **strong**'
      const expected = [
        { type: 'string', name: 'text', value: 'before ', location: loc(1, 7) },
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'unconstrained',
          location: loc(8, input),
          inlines: [{ type: 'string', name: 'text', value: 'strong', location: loc(10, input.length - 2) }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('unconstrained strong spans separated by space', () => {
      const input = '**foo** **bar**'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'unconstrained',
          location: loc(1, 7),
          inlines: [{ type: 'string', name: 'text', value: 'foo', location: loc(3, 5) }],
        },
        { type: 'string', name: 'text', value: ' ', location: loc(8) },
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'unconstrained',
          location: loc(9, input),
          inlines: [{ type: 'string', name: 'text', value: 'bar', location: loc(11, input.length - 2) }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('unconstrained strong preceded by word characters', () => {
      const input = 'before**strong**'
      const expected = [
        { type: 'string', name: 'text', value: 'before', location: loc(1, 6) },
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'unconstrained',
          location: loc(7, input),
          inlines: [{ type: 'string', name: 'text', value: 'strong', location: loc(9, input.length - 2) }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('unconstrained strong followed by word characters', () => {
      const input = '**strong**after'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'unconstrained',
          location: loc(1, 10),
          inlines: [{ type: 'string', name: 'text', value: 'strong', location: loc(3, 8) }],
        },
        { type: 'string', name: 'text', value: 'after', location: loc(11, input) },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('unconstrained strong bounded by word characters', () => {
      const input = 'fe**fi**fo'
      const expected = [
        { type: 'string', name: 'text', value: 'fe', location: loc(1, 2) },
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'unconstrained',
          location: loc(3, 8),
          inlines: [{ type: 'string', name: 'text', value: 'fi', location: loc(5, 6) }],
        },
        { type: 'string', name: 'text', value: 'fo', location: loc(9, input) },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('adjacent unconstrained strong spans', () => {
      const input = '**foo****bar**'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'unconstrained',
          location: loc(1, 7),
          inlines: [{ type: 'string', name: 'text', value: 'foo', location: loc(3, 5) }],
        },
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'unconstrained',
          location: loc(8, input),
          inlines: [{ type: 'string', name: 'text', value: 'bar', location: loc(10, input.length - 2) }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('unconstrained strong spans separated by word', () => {
      const input = '**foo**bar**baz**'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'unconstrained',
          location: loc(1, 7),
          inlines: [{ type: 'string', name: 'text', value: 'foo', location: loc(3, 5) }],
        },
        { type: 'string', name: 'text', value: 'bar', location: loc(8, 10) },
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'unconstrained',
          location: loc(11, input),
          inlines: [{ type: 'string', name: 'text', value: 'baz', location: loc(13, input.length - 2) }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('multiple unconstrained strong within single word', () => {
      const input = 'strong c**hara**cter**s** within a word'
      const expected = [
        { type: 'string', name: 'text', value: 'strong c', location: loc(1, 8) },
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'unconstrained',
          location: loc(9, 16),
          inlines: [{ type: 'string', name: 'text', value: 'hara', location: loc(11, 14) }],
        },
        { type: 'string', name: 'text', value: 'cter', location: loc(17, 20) },
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'unconstrained',
          location: loc(21, 25),
          inlines: [{ type: 'string', name: 'text', value: 's', location: loc(23) }],
        },
        { type: 'string', name: 'text', value: ' within a word', location: loc(26, input) },
      ]
      expect(parse(input)).to.eql(expected)
    })
  })

  describe('constrained with nested markup', () => {
    it('constrained emphasis enclosed in constrained strong', () => {
      const input = '*_strong emphasis_*'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(1, input),
          inlines: [{
            type: 'inline',
            name: 'span',
            variant: 'emphasis',
            form: 'constrained',
            location: loc(2, input.length - 1),
            inlines: [{ type: 'string', name: 'text', value: 'strong emphasis', location: loc(3, input.length - 2) }],
          }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained emphasis enclosed in constrained strong', () => {
      const input = '_*emphasis strong*_'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'emphasis',
          form: 'constrained',
          location: loc(1, input),
          inlines: [{
            type: 'inline',
            name: 'span',
            variant: 'strong',
            form: 'constrained',
            location: loc(2, input.length - 1),
            inlines: [{ type: 'string', name: 'text', value: 'emphasis strong', location: loc(3, input.length - 2) }],
          }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained marked text with multiple marked texts followed by text', () => {
      const input = '_*foo*`bar` baz_'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'emphasis',
          form: 'constrained',
          location: loc(1, input),
          inlines: [
            {
              type: 'inline',
              name: 'span',
              variant: 'strong',
              form: 'constrained',
              location: loc(2, 6),
              inlines: [{ type: 'string', name: 'text', value: 'foo', location: loc(3, 5) }],
            },
            {
              type: 'inline',
              name: 'span',
              variant: 'code',
              form: 'constrained',
              location: loc(7, 11),
              inlines: [{ type: 'string', name: 'text', value: 'bar', location: loc(8, 10) }],
            },
            { type: 'string', name: 'text', value: ' baz', location: loc(12, input.length - 1) },
          ],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('contrained strong that contains unconstrained strong in middle of word', () => {
      const input = '*foo**bar**baz*'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(1, input),
          inlines: [
            { type: 'string', name: 'text', value: 'foo', location: loc(2, 4) },
            {
              type: 'inline',
              name: 'span',
              variant: 'strong',
              form: 'unconstrained',
              location: loc(5, 11),
              inlines: [{ type: 'string', name: 'text', value: 'bar', location: loc(7, 9) }],
            },
            { type: 'string', name: 'text', value: 'baz', location: loc(12, input.length - 1) },
          ],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong that contains unconstrained strong offset by spaces', () => {
      const input = '*foo **bar** baz*'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(1, input),
          inlines: [
            { type: 'string', name: 'text', value: 'foo ', location: loc(2, 5) },
            {
              type: 'inline',
              name: 'span',
              variant: 'strong',
              form: 'unconstrained',
              location: loc(6, 12),
              inlines: [{ type: 'string', name: 'text', value: 'bar', location: loc(8, 10) }],
            },
            { type: 'string', name: 'text', value: ' baz', location: loc(13, input.length - 1) },
          ],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained strong that contains unconstrained strong at start of contents', () => {
      const input = '*** foo ** bar*'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'constrained',
          location: loc(1, input),
          inlines: [
            {
              type: 'inline',
              name: 'span',
              variant: 'strong',
              form: 'unconstrained',
              location: loc(2, 10),
              inlines: [{ type: 'string', name: 'text', value: ' foo ', location: loc(4, 8) }],
            },
            { type: 'string', name: 'text', value: ' bar', location: loc(11, input.length - 1) },
          ],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('constrained code with failed match for nested constrained strong', () => {
      const input = 'such as `(?<v>*)`, where `?<v>` begins a named capture'
      const expected = [
        { type: 'string', name: 'text', value: 'such as ', location: loc(1, 8) },
        {
          type: 'inline',
          name: 'span',
          variant: 'code',
          form: 'constrained',
          location: loc(9, 17),
          inlines: [{ type: 'string', name: 'text', value: '(?<v>*)', location: loc(10, 16) }],
        },
        { type: 'string', name: 'text', value: ', where ', location: loc(18, 25) },
        {
          type: 'inline',
          name: 'span',
          variant: 'code',
          form: 'constrained',
          location: loc(26, 31),
          inlines: [{ type: 'string', name: 'text', value: '?<v>', location: loc(27, 30) }],
        },
        { type: 'string', name: 'text', value: ' begins a named capture', location: loc(32, input) },
      ]
      expect(parse(input)).to.eql(expected)
    })
  })

  describe('unconstrained with nested markup', () => {
    it('unconstrained emphasis enclosed in unconstrained strong', () => {
      const input = '**__strong emphasis__**'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'unconstrained',
          location: loc(1, input),
          inlines: [{
            type: 'inline',
            name: 'span',
            variant: 'emphasis',
            form: 'unconstrained',
            location: loc(3, input.length - 2),
            inlines: [{ type: 'string', name: 'text', value: 'strong emphasis', location: loc(5, input.length - 4) }],
          }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('unconstrained emphasis enclosed in unconstrained strong', () => {
      const input = '__**emphasis strong**__'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'emphasis',
          form: 'unconstrained',
          location: loc(1, input),
          inlines: [{
            type: 'inline',
            name: 'span',
            variant: 'strong',
            form: 'unconstrained',
            location: loc(3, input.length - 2),
            inlines: [{ type: 'string', name: 'text', value: 'emphasis strong', location: loc(5, input.length - 4) }],
          }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })

    it('unconstrained strong that contains uninterpreted constrained strong', () => {
      const input = '**foo*bar***'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'unconstrained',
          location: loc(1, input.length - 1),
          inlines: [{ type: 'string', name: 'text', value: 'foo*bar', location: loc(3, input.length - 3) }],
        },
        { type: 'string', name: 'text', value: '*', location: loc(input.length) },
      ]
      expect(parse(input)).to.eql(expected)
    })

    // NOTE Asciidoctor only get this right by chance
    it('constrained strong enclosed in unconstrained strong', () => {
      const input = '***nested strong***'
      const expected = [
        {
          type: 'inline',
          name: 'span',
          variant: 'strong',
          form: 'unconstrained',
          location: loc(1, input),
          inlines: [{
            type: 'inline',
            name: 'span',
            variant: 'strong',
            form: 'constrained',
            location: loc(3, input.length - 2),
            inlines: [{ type: 'string', name: 'text', value: 'nested strong', location: loc(4, input.length - 3) }],
          }],
        },
      ]
      expect(parse(input)).to.eql(expected)
    })
  })

  describe('macros', () => {
    describe('uninterpreted markup', () => {
      it('unclosed macro', () => {
        const input = 'link:no-more['
        const expected = [{ type: 'string', name: 'text', value: input, location: loc(1, input) }]
        expect(parse(input)).to.eql(expected)
      })

      it('macro with empty target', () => {
        const input = 'link:[]'
        const expected = [{ type: 'string', name: 'text', value: input, location: loc(1, input) }]
        expect(parse(input)).to.eql(expected)
      })

      it('macro whose target begins with space', () => {
        const input = 'link: String[]'
        const expected = [{ type: 'string', name: 'text', value: input, location: loc(1, input) }]
        expect(parse(input)).to.eql(expected)
      })

      it('xref shorthand with target that begins with space', () => {
        const input = '<< exnay>>'
        const expected = [{ type: 'string', name: 'text', value: input, location: loc(1, input) }]
        expect(parse(input)).to.eql(expected)
      })
    })

    describe('URL macro', () => {
      it('URL macro with http target', () => {
        const input = 'http://example.com[]'
        const expected = [{
          type: 'inline',
          name: 'ref',
          variant: 'link',
          target: 'http://example.com',
          location: loc(1, input),
          inlines: [],
        }]
        expect(parse(input)).to.eql(expected)
      })

      it('URL macro with https target', () => {
        const input = 'https://example.com[]'
        const expected = [{
          type: 'inline',
          name: 'ref',
          variant: 'link',
          target: 'https://example.com',
          location: loc(1, input),
          inlines: [],
        }]
        expect(parse(input)).to.eql(expected)
      })

      it('URL macro with link text', () => {
        const input = 'https://example.com[example domain]'
        const expected = [{
          type: 'inline',
          name: 'ref',
          variant: 'link',
          target: 'https://example.com',
          location: loc(1, input),
          inlines: [{ type: 'string', name: 'text', value: 'example domain', location: loc(21, input.length - 1) }],
        }]
        expect(parse(input)).to.eql(expected)
      })

      it('link text with single marked text', () => {
        const input = 'https://example.com[_example only_]'
        const expected = [{
          type: 'inline',
          name: 'ref',
          variant: 'link',
          target: 'https://example.com',
          location: loc(1, input),
          inlines: [
            {
              type: 'inline',
              name: 'span',
              variant: 'emphasis',
              form: 'constrained',
              location: loc(21, input.length - 1),
              inlines: [{ type: 'string', name: 'text', value: 'example only', location: loc(22, input.length - 2) }],
            },
          ],
        }]
        expect(parse(input)).to.eql(expected)
      })

      it.skip('link text with marked text separated by text', () => {
        const input = 'https://example.com[_only_ for *examples*]'
        const expected = [{
          type: 'inline',
          name: 'ref',
          variant: 'link',
          target: 'https://example.com',
          location: loc(1, input),
          inlines: [
            {
              type: 'inline',
              name: 'span',
              variant: 'emphasis',
              form: 'constrained',
              location: loc(21, 26),
              inlines: [{ type: 'string', name: 'text', value: 'only', location: loc(22, 25) }],
            },
            { type: 'string', name: 'text', value: ' for ', location: loc(27, 31) },
            {
              type: 'inline',
              name: 'span',
              variant: 'strong',
              form: 'constrained',
              location: loc(32, input.length - 1),
              inlines: [{ type: 'string', name: 'text', value: 'examples', location: loc(33, input.length - 2) }],
            },
          ],
        }]
        expect(parse(input)).to.eql(expected)
      })
    })

    describe('link macro', () => {
      it('link macro with link text', () => {
        const input = 'link:path/to/home.html[Go to Home]'
        const expected = [{
          type: 'inline',
          name: 'ref',
          variant: 'link',
          target: 'path/to/home.html',
          location: loc(1, input),
          inlines: [{ type: 'string', name: 'text', value: 'Go to Home', location: loc(24, input.length - 1) }],
        }]
        expect(parse(input)).to.eql(expected)
      })

      it('link macro with no link text', () => {
        const input = 'link:report.pdf[]'
        const expected = [{
          type: 'inline',
          name: 'ref',
          variant: 'link',
          target: 'report.pdf',
          location: loc(1, input),
          inlines: [],
        }]
        expect(parse(input)).to.eql(expected)
      })

      it('link macro with URL target', () => {
        const input = 'link:https://example.org[example domain]'
        const expected = [{
          type: 'inline',
          name: 'ref',
          variant: 'link',
          target: 'https://example.org',
          location: loc(1, input),
          inlines: [{ type: 'string', name: 'text', value: 'example domain', location: loc(26, input.length - 1) }],
        }]
        expect(parse(input)).to.eql(expected)
      })

      // Q: should URL macro also work as unconstrained?
      it('works as unconstrained markup', () => {
        const input = 'beforelink:https://example.org[example domain]after'
        const expected = [
          { type: 'string', name: 'text', value: 'before', location: loc(1, 6) },
          {
            type: 'inline',
            name: 'ref',
            variant: 'link',
            target: 'https://example.org',
            location: loc(7, 46),
            inlines: [{ type: 'string', name: 'text', value: 'example domain', location: loc(32, 45) }],
          },
          { type: 'string', name: 'text', value: 'after', location: loc(47, input) },
        ]
        expect(parse(input)).to.eql(expected)
      })
    })

    describe('xref shorthand notation', () => {
      it('target only', () => {
        const input = '<<foo>>'
        const expected = [{
          type: 'inline',
          name: 'ref',
          variant: 'xref',
          target: 'foo',
          location: loc(1, input),
          inlines: [],
        }]
        expect(parse(input)).to.eql(expected)
      })

      it('target with link text', () => {
        const input = '<<foo,link text>>'
        const expected = [{
          type: 'inline',
          name: 'ref',
          variant: 'xref',
          target: 'foo',
          location: loc(1, input),
          inlines: [{ type: 'string', name: 'text', value: 'link text', location: loc(7, input.length - 2) }],
        }]
        expect(parse(input)).to.eql(expected)
      })

      it('target with link text offset by space', () => {
        const input = '<<foo, Foo>>'
        const expected = [{
          type: 'inline',
          name: 'ref',
          variant: 'xref',
          target: 'foo',
          location: loc(1, input),
          inlines: [{ type: 'string', name: 'text', value: 'Foo', location: loc(8, input.length - 2) }],
        }]
        expect(parse(input)).to.eql(expected)
      })

      it('link text with single marked text', () => {
        const input = '<<foo,*bar baz*>>'
        const expected = [{
          type: 'inline',
          name: 'ref',
          variant: 'xref',
          target: 'foo',
          location: loc(1, input),
          inlines: [{
            type: 'inline',
            name: 'span',
            variant: 'strong',
            form: 'constrained',
            location: loc(7, input.length - 2),
            inlines: [{ type: 'string', name: 'text', value: 'bar baz', location: loc(8, input.length - 3) }],
          }],
        }]
        expect(parse(input)).to.eql(expected)
      })

      it.skip('link text with marked text separated by text', () => {
        const input = '<<foo,*bar* > _baz_>>'
        const expected = [{
          type: 'inline',
          name: 'ref',
          variant: 'xref',
          target: 'foo',
          location: loc(1, input),
          inlines: [
            {
              type: 'inline',
              name: 'span',
              variant: 'strong',
              form: 'constrained',
              location: loc(7, 11),
              inlines: [{ type: 'string', name: 'text', value: 'bar', location: loc(8, 10) }],
            },
            { type: 'string', name: 'text', value: ' > ', location: loc(12, 14) },
            {
              type: 'inline',
              name: 'span',
              variant: 'emphasis',
              form: 'constrained',
              location: loc(15, input.length - 2),
              inlines: [{ type: 'string', name: 'text', value: 'baz', location: loc(16, input.length - 3) }],
            },
          ],
        }]
        expect(parse(input)).to.eql(expected)
      })

      it('works as unconstrained markup', () => {
        const input = 'before<<foo>>after'
        const expected = [
          { type: 'string', name: 'text', value: 'before', location: loc(1, 6) },
          {
            type: 'inline',
            name: 'ref',
            variant: 'xref',
            target: 'foo',
            location: loc(7, 13),
            inlines: [],
          },
          { type: 'string', name: 'text', value: 'after', location: loc(14, input) },
        ]
        expect(parse(input)).to.eql(expected)
      })
    })
  })

  describe('preprocessor', () => {
    const makeSourceMapping = (ranges) => {
      const sourceMapping = []
      for (const { range, offset, startOffset = offset, ...entry } of ranges) {
        const range_ = Array.isArray(range) ? range : [range, range]
        if (Array.isArray(offset)) {
          entry.offset = offset
          for (let i = range_[0], to = range_[1]; i <= to; i++) sourceMapping[i] = entry
        } else if (Object.keys(entry).length) {
          let nextOffset = startOffset
          for (let i = range_[0], to = range_[1]; i <= to; i++) {
            sourceMapping[i] = Object.assign({}, entry, { offset: nextOffset++ })
          }
        } else {
          let nextOffset = startOffset
          for (let i = range_[0], to = range_[1]; i <= to; i++) sourceMapping[i] = { offset: nextOffset++ }
        }
      }
      return sourceMapping
    }

    it('should allow inline preprocessor to be deactivated', () => {
      const input = '{name}'
      const attributes = { name: 'Dan' }
      const expected = [{ type: 'string', name: 'text', value: '{name}', location: loc(1, input) }]
      expect(parse(input, { attributes, preprocessorMode: 'none' })).to.eql(expected)
    })

    it('should only return input if preprocessor does not run on input', () => {
      const input = 'nothing to preprocess'
      const expected = { input }
      expect(inlinePreprocessor(input)).to.eql(expected)
    })

    it('should only return input if preprocessor does not match anything', () => {
      const input = '{ + }'
      const expected = { input }
      expect(inlinePreprocessor(input)).to.eql(expected)
    })

    it('should define offset for attribute as range when value is shorter than reference', () => {
      const input = 'hi {name}!'
      const expected = {
        input: 'hi Dan!',
        sourceMapping: makeSourceMapping([
          { range: [0, 2], startOffset: 0 },
          { range: [3, 5], offset: [3, 8], attr: 'name' },
          { range: 6, offset: 9 },
        ]),
      }
      expect(inlinePreprocessor(input, { attributes: { name: 'Dan' } })).to.eql(expected)
    })

    it('should define offset for attribute as range when value is longer than reference', () => {
      const input = 'hi {name}!'
      const expected = {
        input: 'hi Guillaume!',
        sourceMapping: makeSourceMapping([
          { range: [0, 2], startOffset: 0 },
          { range: [3, 11], offset: [3, 8], attr: 'name' },
          { range: 12, offset: 9 },
        ]),
      }
      expect(inlinePreprocessor(input, { attributes: { name: 'Guillaume' } })).to.eql(expected)
    })

    it('should track offsets across multiple attribute references', () => {
      const input = 'The case of {plantiff} vs {defendant}.'
      const attributes = {
        plantiff: 'Wile E. Coyote',
        defendant: 'ACME Corp',
      }
      const expected = {
        input: 'The case of Wile E. Coyote vs ACME Corp.',
        sourceMapping: makeSourceMapping([
          { range: [0, 11], startOffset: 0 },
          { range: [12, 25], offset: [12, 21], attr: 'plantiff' },
          { range: [26, 29], startOffset: 22 },
          { range: [30, 38], offset: [26, 36], attr: 'defendant' },
          { range: 39, offset: 37 },
        ]),
      }
      expect(inlinePreprocessor(input, { attributes })).to.eql(expected)
    })

    it('should track offsets when first attribute value overlaps location of second attribute reference', () => {
      const input = 'A {url-formal-grammar}[formal grammar] for the {url-asciidoc-lang}[AsciiDoc Language].'
      const attributes = {
        'url-asciidoc-lang': 'https://gitlab.eclipse.org/eclipse/asciidoc-lang/asciidoc-lang',
        'url-formal-grammar': 'https://en.wikipedia.org/wiki/Formal_grammar',
      }
      const expected = {
        input: 'A https://en.wikipedia.org/wiki/Formal_grammar[formal grammar] for the ' +
          'https://gitlab.eclipse.org/eclipse/asciidoc-lang/asciidoc-lang[AsciiDoc Language].',
        sourceMapping: makeSourceMapping([
          { range: [0, 1], startOffset: 0 },
          { range: [2, 45], offset: [2, 21], attr: 'url-formal-grammar' },
          { range: [46, 70], startOffset: 22 },
          { range: [71, 132], offset: [47, 65], attr: 'url-asciidoc-lang' },
          { range: [133, 152], startOffset: 66 },
        ]),
      }
      expect(inlinePreprocessor(input, { attributes })).to.eql(expected)
    })

    it('should track location of inline passthrough and replace extent with placeholder', () => {
      const input = '+keep+ pass:[out]!'
      const expected = {
        input: '\x10' + '\0'.repeat(5) + ' \x10' + '\0'.repeat(9) + '!',
        sourceMapping: makeSourceMapping([
          { range: 0, offset: 0, contents: 'keep', form: 'constrained', pass: true },
          { range: [1, 5], startOffset: 1, pass: true },
          { range: 6, offset: 6 },
          { range: 7, offset: 7, contents: 'out', form: 'macro', pass: true },
          { range: [8, 16], startOffset: 8, pass: true },
          { range: 17, offset: 17 },
        ]),
      }
      expect(inlinePreprocessor(input)).to.eql(expected)
    })

    it('should allow initial sourceMapping from previous phase to be specified', () => {
      const input = '{name} +val+.'
      const attributes = { name: 'a' }
      const { input: preprocessedInput, sourceMapping } = inlinePreprocessor(input, { attributes, mode: 'attributes' })
      const expected = {
        input: 'a \x10\0\0\0\0.',
        sourceMapping: makeSourceMapping([
          { range: 0, offset: [0, 5], attr: 'name' },
          { range: 1, offset: 6 },
          { range: 2, offset: 7, contents: 'val', form: 'constrained', pass: true },
          { range: [3, 6], startOffset: 8, pass: true },
          { range: 7, offset: 12 },
        ]),
      }
      expect(inlinePreprocessor(preprocessedInput, { sourceMapping, mode: 'passthroughs' })).to.eql(expected)
    })

    it('should return specified sourceMapping if nothing is matched', () => {
      const input = '{name}'
      const attributes = { name: 'a' }
      const { input: preprocessedInput, sourceMapping } = inlinePreprocessor(input, { attributes, mode: 'attributes' })
      const expected = { input: 'a', sourceMapping }
      expect(inlinePreprocessor(preprocessedInput, { sourceMapping, mode: 'passthroughs' })).to.eql(expected)
    })

    it('should only process attribute references if mode is attributes', () => {
      const input = '{name} +{foo}+ \\{name}.'
      const attributes = { name: 'Dave', foo: 'value' }
      const expected = {
        input: 'Dave +value+ {name}.',
        sourceMapping: makeSourceMapping([
          { range: [0, 3], offset: [0, 5], attr: 'name' },
          { range: [4, 5], startOffset: 6 },
          { range: [6, 10], offset: [8, 12], attr: 'foo' },
          { range: [11, 12], startOffset: 13 },
          { range: 13, startOffset: 15 },
          { range: [14, 19], startOffset: 17 },
        ]),
      }
      expect(inlinePreprocessor(input, { attributes, mode: 'attributes' })).to.eql(expected)
    })

    it('should process backslashes in front of escaped attribute reference', () => {
      const input = 'Use \\\\\\{name} to escape an attribute reference'
      const attributes = { name: 'Not used' }
      const expected = {
        input: 'Use \\{name} to escape an attribute reference',
        sourceMapping: makeSourceMapping([
          { range: [0, 4], startOffset: 0 },
          { range: [5, 43], startOffset: 7 },
        ]),
      }
      expect(inlinePreprocessor(input, { attributes, mode: 'attributes' })).to.eql(expected)
    })

    it('should only process passthroughs if mode is passthroughs', () => {
      const input = '{name} +{name}+'
      const attributes = { name: 'Chris' }
      const expected = {
        input: '{name} \x10\0\0\0\0\0\0\0',
        sourceMapping: makeSourceMapping([
          { range: [0, 6], startOffset: 0 },
          { range: 7, offset: 7, contents: '{name}', form: 'constrained', pass: true },
          { range: [8, 14], startOffset: 8, pass: true },
        ]),
      }
      expect(inlinePreprocessor(input, { attributes, mode: 'passthroughs' })).to.eql(expected)
    })
  })
})
