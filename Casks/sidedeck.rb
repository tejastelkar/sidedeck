cask "sidedeck" do
  version "1.2.0"
  sha256 "ae69924b09ad664efdb8a34a2acfd58760ba54f982ac239f32acd0f0e3ed57df"

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
