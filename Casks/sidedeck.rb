cask "sidedeck" do
  version "1.2.0"
  sha256 "68b6cf2da0ca45431803a6f7daabd6df22758cd87491759ce6ef879c0b1c4d38"

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
