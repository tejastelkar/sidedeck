cask "sidedeck" do
  version "1.0.0"
  sha256 "948320d00b50e42053068f01c25e24ae9a24bd1de394a014aa83b08edc64e75a"

  url "https://tejastelkar.is-a.dev/assets/SideDeck-1.0.dmg"
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
