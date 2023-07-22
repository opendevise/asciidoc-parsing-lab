/* eslint-env mocha */
'use strict'

const { expect, heredoc } = require('#test-harness')
const convertToHTML = require('asciidoc-parsing-lab/html-converter')

describe('html-converter', () => {
  const foldStyles = (html) => html.replace(/<style>[\s\S]+?<\/style>/, '<style>[...]</style>')

  it('standalone with title', () => {
    const asg = JSON.parse(heredoc`
    {
      "name": "document",
      "type": "block",
      "header": {
        "title": [
          {
            "name": "text",
            "type": "string",
            "value": "Document Title"
          }
        ]
      },
      "blocks": [
        {
          "name": "paragraph",
          "type": "block",
          "inlines": [
            {
              "name": "text",
              "type": "string",
              "value": "paragraph"
            }
          ]
        }
      ]
    }
    `)
    const expected = heredoc`
    <!DOCTYPE html>
    <html>
    <head>
    <title>Document Title</title>
    <style>[...]</style>
    </head>
    <body>
    <article>
    <header>
    <h1>Document Title</h1>
    </header>
    <p>paragraph</p>
    </article>
    </body>
    </html>
    `
    expect(foldStyles(convertToHTML(asg))).to.eql(expected)
  })

  it('standalone without title', () => {
    const asg = JSON.parse(heredoc`
    {
      "name": "document",
      "type": "block",
      "blocks": [
        {
          "name": "paragraph",
          "type": "block",
          "inlines": [
            {
              "name": "text",
              "type": "string",
              "value": "paragraph"
            }
          ]
        }
      ]
    }
    `)
    const expected = heredoc`
    <!DOCTYPE html>
    <html>
    <head>
    <style>[...]</style>
    </head>
    <body>
    <article>
    <p>paragraph</p>
    </article>
    </body>
    </html>
    `
    expect(foldStyles(convertToHTML(asg))).to.eql(expected)
  })

  it('embedded without title', () => {
    const asg = JSON.parse(heredoc`
    {
      "name": "document",
      "type": "block",
      "attributes": {
        "embedded": { "value": "" }
      },
      "blocks": [
        {
          "name": "paragraph",
          "type": "block",
          "inlines": [
            {
              "name": "text",
              "type": "string",
              "value": "paragraph"
            }
          ]
        }
      ]
    }
    `)
    const expected = heredoc`
    <article>
    <p>paragraph</p>
    </article>
    `
    expect(convertToHTML(asg)).to.eql(expected)
  })
})
