{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    # Ruby for CocoaPods
    ruby_3_3

    # CocoaPods
    cocoapods

    # Git
    git
  ];

  shellHook = ''
    echo "═══════════════════════════════════════════════════════"
    echo "  SelfControl Development Environment"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    echo "Ruby: $(ruby --version)"
    echo "CocoaPods: $(pod --version 2>/dev/null || echo 'not available')"
    echo ""

    # Check for Xcode
    if ! /usr/bin/xcode-select -p 2>/dev/null | grep -q "Xcode.app"; then
      echo "⚠️  WARNING: Full Xcode required (not just Command Line Tools)"
      echo "   Install from: https://apps.apple.com/app/xcode/id497799835"
      echo "   Then run: sudo xcode-select -s /Applications/Xcode.app"
      echo ""
    fi

    echo "To build:"
    echo "  1. git submodule update --init --recursive"
    echo "  2. pod install"
    echo "  3. xcodebuild -workspace SelfControl.xcworkspace -scheme SelfControl build"
    echo ""
    echo "Or open SelfControl.xcworkspace in Xcode"
    echo "═══════════════════════════════════════════════════════"
  '';
}
