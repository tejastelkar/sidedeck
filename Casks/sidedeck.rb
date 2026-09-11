cask "sidedeck" do
  version "1.2.0"
  sha256 "54841448c822e33b4bce516f037ef6bf687e86155b18f30c6c5776d9b0cc3f4d"

  url "https://tejastelkar.is-a.dev/assets/SideDeck-1.2.0.dmg"
  name "SideDeck"
  desc "Ambient floating edge dock utility for macOS"
  homepage "https://tejastelkar.is-a.dev/sidedeck"

  auto_updates true
  depends_on macos: ">= :sonoma"

  app "SideDeck.app"

  zap trash: [
    "~/Library/Application Support/com.tejastelkar.sidedeck",
    "~/Library/Preferences/com.tejastelkar.sidedeck.plist",
  ]
end
