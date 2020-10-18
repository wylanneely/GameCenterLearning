/// Copyright (c) 2018 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import GameKit

final class GameCenterManager: NSObject, GKGameCenterControllerDelegate {
    
    override init() {
        super.init()
        GKLocalPlayer.local.authenticateHandler = { gcAuthVC, error in
            if GKLocalPlayer.local.isAuthenticated {
                NotificationCenter.default.post(name: .authenticationChanged, object: GKLocalPlayer.local.isAuthenticated)
                GKLocalPlayer.local.register(self)
            } else if let vc = gcAuthVC {
                self.viewController?.present(vc, animated: true)
                print("presented GameCenterAuthViewController")
            } else {
                print("Error authentication to GameCenter: " +
                        "\(error?.localizedDescription ?? "none")") }
        }
    }
    
    //MARK: Properties
    static let manager = GameCenterManager()
    
    static var isAuthenticated: Bool {
            return GKLocalPlayer.local.isAuthenticated
        }

    var viewController: UIViewController?
    var currentMatchmakerVC: GKTurnBasedMatchmakerViewController?
    var currentMatch: GKTurnBasedMatch?
    
    typealias CompletionBlock = (Error?) -> Void
 
    var canTakeTurnForCurrentMatch: Bool {
        guard let match = currentMatch else { return true }
        return match.isLocalPlayersTurn
    }
    
    func presentMatchmaker() {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.inviteMessage = "Would you like to play Nine Knights?"
        let vc = GKTurnBasedMatchmakerViewController(matchRequest: request)
        vc.turnBasedMatchmakerDelegate = self
        currentMatchmakerVC = vc
        viewController?.present(vc, animated: true)
    }
    
    enum GameCenterHelperError: Error {
        case matchNotFound
    }
    
    func endTurn(_ model: GameModel, completion: @escaping CompletionBlock) {
      // 1
      guard let match = currentMatch else {
        completion(GameCenterHelperError.matchNotFound)
        return
      }
      
      do {
        match.message = model.messageToDisplay
        
        // 2
        match.endTurn(
          withNextParticipants: match.others,
          turnTimeout: GKExchangeTimeoutDefault,
          match: try JSONEncoder().encode(model),
          completionHandler: completion
        )
      } catch {
        completion(error)
      }
    }

    func win(completion: @escaping CompletionBlock) {
      guard let match = currentMatch else {
        completion(GameCenterHelperError.matchNotFound)
        return
      }
      
      // 3
      match.currentParticipant?.matchOutcome = .won
      match.others.forEach { other in
        other.matchOutcome = .lost
      }
      
      match.endMatchInTurn(
        withMatch: match.matchData ?? Data(),
        completionHandler: completion
      )
    }

    
    //MARK: GKGameCenter
    
    let gameCenterPlayerProfileVC = GKGameCenterViewController(
          state: .localPlayerProfile)
      
      func presentGameCenterProfile(){
          let vc = gameCenterPlayerProfileVC
          gameCenterPlayerProfileVC.gameCenterDelegate = self
          viewController?.present(vc, animated: true, completion: nil)
      }
    
    func submitScoreToLeaderboard(){
        GKLeaderboard.submitScore(10, context: 0, player: GKLocalPlayer.local, leaderboardIDs: ["com.wylan.nineknights.leaderboards"]) { (error) in
            
        }
    }
      
    //MARK: Delegate
    
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterPlayerProfileVC.dismiss(animated: true, completion: nil)
    }
        

}

extension GameCenterManager: GKTurnBasedMatchmakerViewControllerDelegate {
  func turnBasedMatchmakerViewControllerWasCancelled(
    _ viewController: GKTurnBasedMatchmakerViewController) {
      viewController.dismiss(animated: true)
  }
  func turnBasedMatchmakerViewController(
    _ viewController: GKTurnBasedMatchmakerViewController,
    didFailWithError error: Error) {
      print("Matchmaker vc did fail with error: \(error.localizedDescription).")
  }
}

extension GameCenterManager: GKLocalPlayerListener {
    
    func player(_ player: GKPlayer, wantsToQuitMatch match: GKTurnBasedMatch) {
        let activeOthers = match.others.filter { other in
            return other.status == .active
        }
        match.currentParticipant?.matchOutcome = .lost
        activeOthers.forEach { participant in
            participant.matchOutcome = .won
        }
        match.endMatchInTurn(
            withMatch: match.matchData ?? Data()
        )
    }
    
    func player(_ player: GKPlayer,
                receivedTurnEventFor match: GKTurnBasedMatch,
                didBecomeActive: Bool ) {
        if let vc = currentMatchmakerVC {
            currentMatchmakerVC = nil
            vc.dismiss(animated: true)
        }
        guard didBecomeActive else { return }
        NotificationCenter.default.post(name: .presentGame, object: match)
    }
}

extension Notification.Name {
  static let presentGame = Notification.Name(rawValue: "presentGame")
  static let authenticationChanged = Notification.Name(rawValue: "authenticationChanged")
}

