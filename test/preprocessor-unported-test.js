/* eslint-env mocha */
'use strict'

const { expect, heredoc } = require('#test-harness')
const { parse } = require('#preprocessor-parser')

describe('preprocessor', () => {
  const location = (spec) => {
    const [line, col, lineOffset] = spec.split(':').map(Number)
    return { line, col, lineOffset }
  }

  it('should process empty input', () => {
    const input = ''
    const expected = {
      input,
      locations: {},
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should process non-empty input with no preprocessor directives', () => {
    const input = heredoc`
    foo
    bar
    baz
    `
    const expected = {
      input,
      locations: { 1: location('1:1:0'), 2: location('2:1:0'), 3: location('3:1:0') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should preserve trailing newline in input', () => {
    const input = heredoc`
    foo
    bar
    `
    const expected = {
      input: input + '\n',
      locations: { 1: location('1:1:0'), 2: location('2:1:0') },
    }
    expect(parse(input + '\n')).to.eql(expected)
  })

  it('should preserve trailing newlines in input', () => {
    const input = heredoc`
    foo
    bar
    `
    const expected = {
      input: input + '\n\n',
      locations: { 1: location('1:1:0'), 2: location('2:1:0'), 3: location('3:1:0') },
    }
    expect(parse(input + '\n\n')).to.eql(expected)
  })

  it('should process input with true single-line preprocessor conditional', () => {
    const input = 'ifndef::foo[foo is not set]'
    const expected = {
      input: 'foo is not set',
      locations: { 1: location('1:13:0') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should retain trailing newline after true single-line preprocessor conditional', () => {
    const input = 'ifndef::foo[foo is not set]\n'
    const expected = {
      input: 'foo is not set\n',
      locations: { 1: location('1:13:0') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should process input with false single-line preprocessor conditional', () => {
    const input = 'ifdef::foo[foo is set]'
    const expected = {
      input: '',
      locations: {},
    }
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
      locations: { 1: location('1:13:0'), 2: location('2:1:0') },
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
      locations: { 1: location('2:1:1') },
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
      locations: { 1: location('1:1:0'), 2: location('2:13:0') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should process input with true single-line preprocessor conditional preceded by other lines', () => {
    const input = heredoc`
    début
    ifdef::foo[foo is set]
    `
    const expected = {
      input: 'début\n',
      locations: { 1: location('1:1:0') },
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
      locations: { 1: location('1:1:0'), 2: location('2:13:0'), 3: location('3:1:0') },
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
      locations: { 1: location('1:1:0'), 2: location('3:1:1') },
    }
    expect(parse(input)).to.eql(expected)
  })

  it('should process input with only true preprocessor conditional enclosure', () => {
    const input = heredoc`
    ifndef::foo[]
    foo is not set
    endif::[]
    `
    const expected = {
      input: 'foo is not set\n',
      locations: { 1: location('2:1:1') },
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
      locations: { 1: location('2:1:1'), 2: location('4:1:2') },
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
      locations: { 1: location('1:1:0'), 2: location('3:1:1') },
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
      locations: { 1: location('1:1:0'), 2: location('3:1:1'), 3: location('5:1:2') },
    }
    expect(parse(input)).to.eql(expected)
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
      locations: { 1: location('1:1:0'), 2: location('2:1:0'), 3: location('3:12:0') },
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
      locations: { 1: location('1:1:0'), 2: location('2:1:0'), 3: location('3:1:0'), 4: location('4:12:0') },
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
      locations: { 1: location('1:1:0'), 2: location('2:1:0'), 3: location('3:17:0') },
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
      locations: { 1: location('1:1:0'), 2: location('2:1:0'), 3: location('3:21:0') },
    }
    expect(parse(input)).to.eql(expected)
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
      locations: { 1: location('1:1:0'), 2: location('2:1:0'), 3: location('3:1:0'), 4: location('5:1:1') },
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
      locations: { 1: location('1:1:0'), 2: location('2:1:0'), 3: location('3:1:0'), 4: location('4:1:0'), 5: location('6:1:1') },
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
        1: location('1:1:0'),
        2: location('2:1:0'),
        3: location('3:1:0'),
        4: location('5:1:1'),
        5: location('7:1:2'),
        6: location('8:1:2'),
      },
    }
    expect(parse(input)).to.eql(expected)
  })
})
