import Testing
@testable import ScriptureLLM

@Suite struct SSEParserTests {
    @Test func eventsSplitAcrossChunksAreReassembled() {
        var parser = SSEParser()
        #expect(parser.feed("event: content_block_delta\ndata: {\"a\":") == [])
        #expect(parser.feed("1}\n\n") == [SSEEvent(name: "content_block_delta", data: "{\"a\":1}")])
    }

    @Test func multipleDataLinesJoinAndCommentsAreIgnored() {
        var parser = SSEParser()
        let events = parser.feed(": ping\ndata: one\ndata:two\n\ndata: [DONE]\n\n")
        #expect(events == [SSEEvent(name: nil, data: "one\ntwo"), SSEEvent(name: nil, data: "[DONE]")])
    }

    @Test func carriageReturnsAndFinishAreHandled() {
        var parser = SSEParser()
        #expect(parser.feed("data: a\r\n\r\ndata: b") == [SSEEvent(name: nil, data: "a")])
        #expect(parser.finish() == [SSEEvent(name: nil, data: "b")])
        #expect(parser.finish() == [])
    }

    @Test func bytesSplitInsideAMultibyteCharacterAreHeld() {
        var parser = SSEParser()
        let bytes = Array("data: é\n\n".utf8)
        #expect(parser.feed(bytes[..<7]) == [])
        #expect(parser.feed(bytes[7...]) == [SSEEvent(name: nil, data: "é")])
    }
}
