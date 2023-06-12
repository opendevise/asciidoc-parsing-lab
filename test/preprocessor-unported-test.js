/* eslint-env mocha */
'use strict'

const { expect, heredoc } = require('#test-harness')
const { parse } = require('#preprocessor-parser')
const ospath = require('node:path')

describe('preprocessor', () => {
  const loc = (spec, file) => {
    const [line, col, lineOffset] = spec.split(':').map(Number)
    return file ? { line, col, lineOffset, file } : { line, col, lineOffset }
  }

  it('should process empty input', () => {
    const input = ''
    const expected = { input }
    expect(parse(input)).to.eql(expected)
  })

  it('should process non-empty input with no preprocessor directives', () => {
    const input = heredoc`
    foo
    bar
    baz
    `
    const expected = { input }
    expect(parse(input)).to.eql(expected)
  })

  it('should preserve trailing newline in input', () => {
    const inputBase = heredoc`
    foo
    bar
    `
    const input = inputBase + '\n'
    const expected = { input }
    expect(parse(input)).to.eql(expected)
  })

  it('should preserve trailing newlines in input', () => {
    const inputBase = heredoc`
    foo
    bar
    `
    const input = inputBase + '\n\n'
    const expected = { input }
    expect(parse(input)).to.eql(expected)
  })

  it('should process input with true single-line preprocessor conditional', () => {
    const input = 'ifndef::foo[foo is not set]'
    const expected = {
      input: 'foo is not set',
      locations: { 1: loc('1:13:0') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should retain trailing newline after true single-line preprocessor conditional', () => {
    const input = 'ifndef::foo[foo is not set]\n'
    const expected = {
      input: 'foo is not set\n',
      locations: { 1: loc('1:13:0'), 2: loc('2:1:0') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should process input with false single-line preprocessor conditional', () => {
    const input = 'ifdef::foo[foo is set]'
    const expected = { input: '', locations: {} }
    expect(parse(input)).to.eql(expected)
  })

  it('should process input with true single-line preprocessor conditional followed by other lines', () => {
    const input = heredoc`
    ifndef::foo[foo is not set]
    fin
    `
    const expected = {
      input: heredoc`
      foo is not set
      fin
      `,
      locations: { 1: loc('1:13:0'), 2: loc('2:1:0') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should process input with false single-line preprocessor conditional followed by other lines', () => {
    const input = heredoc`
    ifdef::foo[foo is set]
    fin
    `
    const expected = {
      input: 'fin',
      locations: { 1: loc('2:1:1') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should process input with false single-line preprocessor conditional followed by empty line', () => {
    const input = heredoc`
    ifdef::foo[foo is set]

    fin
    `
    const expected = {
      input: '\nfin',
      locations: { 1: loc('2:1:1'), 2: loc('3:1:1') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should process input with true single-line preprocessor conditional preceded by other lines', () => {
    const input = heredoc`
    début
    ifndef::foo[foo is not set]
    `
    const expected = {
      input: heredoc`
      début
      foo is not set
      `,
      locations: { 1: loc('1:1:0'), 2: loc('2:13:0') },
    }
    expect(parse(input)).to.eql(expected)
  })

  // FIXME maybe don't keep trailing newline in this case?
  it('should process input with false single-line preprocessor conditional preceded by other lines', () => {
    const input = heredoc`
    début
    ifdef::foo[foo is set]
    `
    const expected = {
      input: 'début\n',
      locations: { 1: loc('1:1:0'), 2: loc('2:1:0') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should process input with true single-line preprocessor conditional surrounded by other lines', () => {
    const input = heredoc`
    début
    ifndef::foo[foo is not set]
    fin
    `
    const expected = {
      input: heredoc`
      début
      foo is not set
      fin`,
      locations: { 1: loc('1:1:0'), 2: loc('2:13:0'), 3: loc('3:1:0') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should process input with false single-line preprocessor conditional surrounded by other lines', () => {
    const input = heredoc`
    début
    ifdef::foo[foo is set]
    fin
    `
    const expected = {
      input: heredoc`
      début
      fin
      `,
      locations: { 1: loc('1:1:0'), 2: loc('3:1:1') },
    }
    expect(parse(input)).to.eql(expected)
  })

  // FIXME maybe don't keep trailing newline in this case?
  it('should process input with only true preprocessor conditional enclosure', () => {
    const input = heredoc`
    ifndef::foo[]
    foo is not set
    endif::[]
    `
    const expected = {
      input: 'foo is not set\n',
      locations: { 1: loc('2:1:1'), 2: loc('4:1:2') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should process input with only true preprocessor conditional enclosure followed by other lines', () => {
    const input = heredoc`
    ifndef::foo[]
    foo is not set
    endif::[]
    fin
    `
    const expected = {
      input: heredoc`
      foo is not set
      fin
      `,
      locations: { 1: loc('2:1:1'), 2: loc('4:1:2') },
    }
    expect(parse(input)).to.eql(expected)
  })

  // FIXME maybe don't keep trailing newline in this case?
  it('should process input with only true preprocessor conditional enclosure preceded by other lines', () => {
    const input = heredoc`
    début
    ifndef::foo[]
    foo is not set
    endif::[]
    `
    const expected = {
      input: heredoc`
      début
      foo is not set
      ` + '\n',
      locations: { 1: loc('1:1:0'), 2: loc('3:1:1'), 3: loc('5:1:2') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should process input with only true preprocessor conditional enclosure surrounded by other lines', () => {
    const input = heredoc`
    début
    ifndef::foo[]
    foo is not set
    endif::[]
    fin
    `
    const expected = {
      input: heredoc`
      début
      foo is not set
      fin
      `,
      locations: { 1: loc('1:1:0'), 2: loc('3:1:1'), 3: loc('5:1:2') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should process negated preprocessor conditional with attribute alternatives that evaluates to false', () => {
    const input = heredoc`
    début
    ifdef::foo,bar[foo or bar is set]
    fin
    `
    const expected = {
      input: heredoc`
      début
      fin
      `,
      locations: { 1: loc('1:1:0'), 2: loc('3:1:1') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should process negated preprocessor conditional with attribute combination that evaluates to false', () => {
    const input = heredoc`
    début
    ifdef::foo+bar[foo and bar are set]
    fin
    `
    const expected = {
      input: heredoc`
      début
      fin
      `,
      locations: { 1: loc('1:1:0'), 2: loc('3:1:1') },
    }
    expect(parse(input, { attributes: { foo: '' } })).to.eql(expected)
  })

  it('should process preprocessor conditional with attribute alternatives that evaluates to true', () => {
    const input = heredoc`
    début
    ifdef::foo,bar[foo or bar is set]
    fin
    `
    const expected = {
      input: heredoc`
      début
      foo or bar is set
      fin
      `,
      locations: { 1: loc('1:1:0'), 2: loc('2:16:0'), 3: loc('3:1:0') },
    }
    expect(parse(input, { attributes: { foo: '' } })).to.eql(expected)
  })

  it('should process negated preprocessor conditional with attribute alternatives that evaluates to true', () => {
    const input = heredoc`
    début
    ifndef::foo,bar[foo and bar are not set]
    fin
    `
    const expected = {
      input: heredoc`
      début
      foo and bar are not set
      fin
      `,
      locations: { 1: loc('1:1:0'), 2: loc('2:17:0'), 3: loc('3:1:0') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should process preprocessor conditional with attribute combination that evaluates to true', () => {
    const input = heredoc`
    début
    ifdef::foo+bar[foo and bar are set]
    fin
    `
    const expected = {
      input: heredoc`
      début
      foo and bar are set
      fin
      `,
      locations: { 1: loc('1:1:0'), 2: loc('2:16:0'), 3: loc('3:1:0') },
    }
    expect(parse(input, { attributes: { foo: '', bar: '' } })).to.eql(expected)
  })

  it('should process negated preprocessor conditional with attribute combination that evaluates to true', () => {
    const input = heredoc`
    début
    ifndef::foo+bar[foo or bar is not set]
    fin
    `
    const expected = {
      input: heredoc`
      début
      foo or bar is not set
      fin
      `,
      locations: { 1: loc('1:1:0'), 2: loc('2:17:0'), 3: loc('3:1:0') },
    }
    expect(parse(input, { attributes: { foo: '' } })).to.eql(expected)
  })

  it('should process and retain attribute entry above preprocessor conditional', () => {
    const input = heredoc`
    :foo:

    ifdef::foo[foo is set]
    `
    const expected = {
      input: heredoc`
      :foo:

      foo is set
      `,
      locations: { 1: loc('1:1:0'), 2: loc('2:1:0'), 3: loc('3:12:0') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should process and retain multiple attribute entries above preprocessor conditional', () => {
    const input = heredoc`
    :toc: left
    :foo:

    ifdef::foo[foo is set]
    `
    const expected = {
      input: heredoc`
      :toc: left
      :foo:

      foo is set
      `,
      locations: { 1: loc('1:1:0'), 2: loc('2:1:0'), 3: loc('3:1:0'), 4: loc('4:12:0') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should process attribute entry when name of attribute contains hyphen', () => {
    const input = heredoc`
    :app-name: ACME

    ifdef::app-name[app-name is set]
    `
    const expected = {
      input: heredoc`
      :app-name: ACME

      app-name is set
      `,
      locations: { 1: loc('1:1:0'), 2: loc('2:1:0'), 3: loc('3:17:0') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should process attribute entry when name of attribute contains hyphen', () => {
    const input = heredoc`
    :project_name: asciidoc-lang

    ifdef::project_name[asciidoc-lang is set]
    `
    const expected = {
      input: heredoc`
      :project_name: asciidoc-lang

      asciidoc-lang is set
      `,
      locations: { 1: loc('1:1:0'), 2: loc('2:1:0'), 3: loc('3:21:0') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should consult attribute in attributes passed from API', () => {
    const attributes = { foo: 'bar' }
    const input = heredoc`
    ifdef::foo[foo is set]
    fin
    `
    const expected = {
      input: heredoc`
      foo is set
      fin
      `,
      locations: { 1: loc('1:12:0'), 2: loc('2:1:0') },
    }
    expect(parse(input, { attributes })).to.eql(expected)
  })

  it('should not modify attributes passed from API when processing attribute entry', () => {
    const attributes = { foo: 'bar' }
    const input = heredoc`
    :yin: yang

    ifdef::foo[foo is set]
    ifdef::yin[yin is set]
    `
    const expected = {
      input: heredoc`
      :yin: yang

      foo is set
      yin is set
      `,
      locations: { 1: loc('1:1:0'), 2: loc('2:1:0'), 3: loc('3:12:0'), 4: loc('4:12:0') },
    }
    expect(parse(input, { attributes })).to.eql(expected)
    expect(Object.keys(attributes)).to.eql(['foo'])
  })

  it('should not process attribute entry in paragraph', () => {
    const input = heredoc`
    paragraph
    :foo:

    ifdef::foo[foo is set]
    fin
    `
    const expected = {
      input: heredoc`
      paragraph
      :foo:

      fin
      `,
      locations: { 1: loc('1:1:0'), 2: loc('2:1:0'), 3: loc('3:1:0'), 4: loc('5:1:1') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should not process attribute entry in verbatim block', () => {
    const input = heredoc`
    ----
    :foo:
    ----

    ifdef::foo[foo is set]
    fin
    `
    const expected = {
      input: heredoc`
      ----
      :foo:
      ----

      fin
      `,
      locations: {
        1: loc('1:1:0'),
        2: loc('2:1:0'),
        3: loc('3:1:0'),
        4: loc('4:1:0'),
        5: loc('6:1:1'),
      },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should process preprocessor directive in verbatim content', () => {
    const input = heredoc`
    :foo:

    ----
    ifdef::foo[]
    foo
    endif::[]
    bar
    ----
    `
    const expected = {
      input: heredoc`
      :foo:

      ----
      foo
      bar
      ----
      `,
      locations: {
        1: loc('1:1:0'),
        2: loc('2:1:0'),
        3: loc('3:1:0'),
        4: loc('5:1:1'),
        5: loc('7:1:2'),
        6: loc('8:1:2'),
      },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should compute offsets for empty include correctly', () => {
    const input = heredoc`
    before
    include::partial-empty.adoc[]
    after
    `
    const expected = {
      input: heredoc`
      before
      after
      `,
      locations: {
        1: loc('1:1:0'),
        2: loc('3:1:1'),
      },
    }
    expect(parse(input, { attributes: { docdir: ospath.join(__dirname, 'fixtures') } })).to.eql(expected)
  })

  it('should compute offsets for non-empty include correctly', () => {
    const input = heredoc`
    before
    include::partial.adoc[]
    after
    `
    const expected = {
      input: heredoc`
      before
      partial
      after
      `,
      locations: {
        1: loc('1:1:0'),
        2: loc('1:1:0', ['partial.adoc']),
        3: loc('3:1:0'),
      },
    }
    expect(parse(input, { attributes: { docdir: ospath.join(__dirname, 'fixtures') } })).to.eql(expected)
  })

  it('should compute offsets for non-empty include without trailing newline correctly', () => {
    const input = heredoc`
    before
    include::partial-noeol.adoc[]
    after
    `
    const expected = {
      input: heredoc`
      before
      partial
      after
      `,
      locations: {
        1: loc('1:1:0'),
        2: loc('1:1:0', ['partial-noeol.adoc']),
        3: loc('3:1:0'),
      },
    }
    expect(parse(input, { attributes: { docdir: ospath.join(__dirname, 'fixtures') } })).to.eql(expected)
  })

  it('should compute offsets for trailing non-empty include without trailing newline correctly', () => {
    const input = heredoc`
    before
    include::partial-noeol.adoc[]
    `
    const expected = {
      input: 'before\npartial',
      locations: {
        1: loc('1:1:0'),
        2: loc('1:1:0', ['partial-noeol.adoc']),
      },
    }
    expect(parse(input, { attributes: { docdir: ospath.join(__dirname, 'fixtures') } })).to.eql(expected)
  })

  it('should compute offsets for non-empty include without trailing newline followed by newline correctly', () => {
    const inputBase = heredoc`
    before
    include::partial-noeol.adoc[]
    `
    const input = inputBase + '\n'
    const expected = {
      input: 'before\npartial\n',
      locations: {
        1: loc('1:1:0'),
        2: loc('1:1:0', ['partial-noeol.adoc']),
        3: loc('3:1:0'),
      },
    }
    expect(parse(input, { attributes: { docdir: ospath.join(__dirname, 'fixtures') } })).to.eql(expected)
  })

  it('should compute offsets for trailing non-empty include with trailing newline correctly', () => {
    const input = heredoc`
    before
    include::partial.adoc[]
    `
    const expected = {
      input: 'before\npartial\n',
      locations: {
        1: loc('1:1:0'),
        2: loc('1:1:0', ['partial.adoc']),
        3: loc('2:1:0', ['partial.adoc']),
      },
    }
    expect(parse(input, { attributes: { docdir: ospath.join(__dirname, 'fixtures') } })).to.eql(expected)
  })

  it('should compute offsets for non-empty include with trailing newline followed by newline correctly', () => {
    const inputBase = heredoc`
    before
    include::partial.adoc[]
    `
    const input = inputBase + '\n'
    const expected = {
      input: 'before\npartial\n',
      locations: {
        1: loc('1:1:0'),
        2: loc('1:1:0', ['partial.adoc']),
        3: loc('3:1:0'),
      },
    }
    expect(parse(input, { attributes: { docdir: ospath.join(__dirname, 'fixtures') } })).to.eql(expected)
  })
})
