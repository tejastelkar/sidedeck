cask "sidedeck" do
  version "1.1.1"
  sha256 "98099b7be3f21896fc7f7d416a791202f896ce3ca0ca8a441438bf74e843d01d"

  url "https://tejastelkar.is-a.dev/assets/SideDeck-1.1.1.dmg"
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
