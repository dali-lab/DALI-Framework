// https://github.com/Quick/Quick

import Quick
import Nimble
import DALI

class SocketSpec: QuickSpec {
	override func spec() {
		DALIapi.configure(config: DALIConfig(dict: NSDictionary(dictionary: [
			"server_url": "http://localhost:3000"
			])))
		
        describe("sockets") {
			it("works") {
				DALIEvent.observeUpcoming(callback: { (events, error) in
					print(events?.count ?? -1)
				})
			}
        }
    }
}
