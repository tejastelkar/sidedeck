cask "sidedeck" do
  version "1.2.0"
  sha256 "eef70ffeb461e9c5e65d400f43437b841bd1d245e6019e9cc499cea75ad94631"

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
