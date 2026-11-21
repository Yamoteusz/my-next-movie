import Foundation
import Testing

@testable import MyNextMovie

@MainActor
struct LocalModelTests {
    @Test func decodesFiltersFromTheChatAnswer() throws {
        let filters = makeMovieFilters(genres: [35], from: 1990, to: 1999, people: ["Keanu Reeves"])
        let json = String(decoding: try JSONEncoder().encode(filters), as: UTF8.self)
        let answer = try JSONSerialization.data(withJSONObject: [
            "choices": [["message": ["content": json]]]
        ])
        #expect(try decodeLocalModelFilters(answer) == filters)
    }

    @Test func answerWithoutFiltersIsAnError() {
        let json = Data("{\"choices\":[{\"message\":{\"content\":\"No filters\"}}]}".utf8)
        #expect(throws: LocalModelError.self) { try decodeLocalModelFilters(json) }
    }

    @Test func answerWithoutChoicesIsAnError() {
        #expect(throws: LocalModelError.self) {
            try decodeLocalModelFilters(Data("{\"choices\":[]}".utf8))
        }
        #expect(throws: LocalModelError.self) { try decodeLocalModelFilters(Data("{}".utf8)) }
    }

    @Test func timeoutIsNotAStoppedServer() {
        #expect(
            localModelConnectionMessage(URLError(.timedOut))
                == "The local model took too long to answer. Try again.")
        #expect(
            localModelConnectionMessage(URLError(.cannotConnectToHost))
                == "The local model is not running. Start llama-server.")
    }

    @Test func requestSendsTheWishAndTheSchema() throws {
        let data = try localModelRequestBody(wish: "coś lekkiego z Keanu")
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let messages = try #require(body["messages"] as? [[String: String]])
        #expect(messages.last?["content"] == "coś lekkiego z Keanu")
        #expect(messages.first?["role"] == "system")
        #expect(body["temperature"] as? Int == 0)
        #expect(body["max_tokens"] as? Int == 300)
        let format = try #require(body["response_format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        let schema = try #require(format["json_schema"] as? [String: Any])
        #expect(schema["strict"] as? Bool == true)
        let definition = try #require(schema["schema"] as? [String: Any])
        #expect(
            Set(definition["required"] as? [String] ?? []) == [
                "genreIds", "fromYear", "toYear", "people", "keywords", "title",
            ])
    }

    @Test func instructionsListEveryGenre() {
        for genre in genreTable {
            #expect(localModelInstructions().contains("\(genre.id) \(genre.name)"))
        }
    }
}
