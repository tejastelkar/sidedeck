cask "sidedeck" do
  version "1.2.0"
  sha256 :no_check

  url "https://sidedeck.tejastelkar.com/assets/SideDeck-1.2.0.dmg"
  name "SideDeck"
  desc "1:1 Native macOS floating dock & productivity cards"
  homepage "https://sidedeck.tejastelkar.com"

  depends_on macos: ">= :sonoma"

  app "SideDeck.app"

  zap trash: [
    "~/Library/Application Support/SideDeck",
    "~/Library/Preferences/com.tejastelkar.sidedeck.plist",
  ]
end
