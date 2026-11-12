# Move

Moves the focused window to a frame on its screen when you press a shortcut.
It is a small app with no Dock icon that runs in the background under launchd
and reads its shortcuts from a YAML file. The `move` command checks the
config.

## Config

`move` reads `~/.config/move/config.yaml`, or
`$XDG_CONFIG_HOME/move/config.yaml` when that is set.

```yaml
bindings:
  cmd+shift+1:      { w: 1/2, h: 1 }
  cmd+shift+2:      { x: 1/2, w: 1/2, h: 1 }
  cmd+return:       { w: 1, h: 1 }
  cmd+shift+return: { w: 3/4, h: 1, center: true }
```

A shortcut is one or more modifiers and one key, joined with `+`, in
lowercase:

- Modifiers: `cmd`, `shift`, `alt` (or `opt`) and `ctrl`, in any order.
- Keys: `a` to `z`, `0` to `9`, `return` (or `enter`), `space`, `tab`,
  `escape`, `left`, `right`, `up`, `down` and `f1` to `f12`.

A frame is given as fractions of the screen's usable area, which leaves out
the menu bar and the Dock:

- `w` and `h` are required. `x` and `y` default to 0 and count from the top
  left.
- A value can be written as `1/2`, `0.5` or `1`.
- `center: true` centers the window both ways and can't be used with `x` or
  `y`.

`move` reloads the file when it changes. If the new file has an error, the old
shortcuts stay active and the error goes to the log. To check a file without
reloading:

```sh
move check
move check --config path/to/config.yaml
```

To keep the config in dotfiles:

```sh
mkdir -p ~/.config/move
ln -s ~/.dotfiles/move/config.yaml ~/.config/move/config.yaml
```

## Install

Move needs the Accessibility permission to move other apps' windows. macOS
ties the permission to the app's signature, so sign it with the same
certificate every time. Otherwise you have to grant the permission again after
every rebuild.

Create the certificate once, then build, sign and start Move:

```sh
make cert
make install
```

`make cert` creates a self-signed code signing certificate named `move` in the
login keychain, and does nothing when it exists. Keychain Access shows it as
not trusted, which doesn't stop signing.

This installs `~/Applications/Move.app`, links `~/.local/bin/move` to its
binary, installs `~/Library/LaunchAgents/local.move.plist` and starts the
agent. On first start, macOS asks for the permission. Turn on Move in System
Settings, Device Control and Data Access. Before macOS 27 the list is called
Accessibility, under Privacy & Security. If Move is missing from the list,
click `+` and add `~/Applications/Move.app`.

To use another certificate, run `make install SIGN_ID="name"`. `SIGN_ID=-`
signs ad hoc, which loses the permission on every rebuild.

## Commands

```sh
make test       # run the unit tests
make cert       # create the signing certificate if it is missing
make install    # build, sign, install and start or restart the agent
make restart    # restart the agent
make log        # follow ~/Library/Logs/move.log
make uninstall  # stop the agent and remove the app, link and plist
```
