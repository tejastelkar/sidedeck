cask "sidedeck" do
  version "1.2.0"
  sha256 "bc3b70e9a3719f0f5b639a2ab6f78c56b8b848852db5e454d87df2534ff3801e"

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
