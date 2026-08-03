# Capturing environments

`bootprint capture` writes `bootprint.lock`; `bootprint capture local` writes `.bootprint/local.json`. Use `--output`, `--env NAME`, `--required-env NAME`, and `--privacy strict` to control the capture.

The snapshot includes runtime, dependency, native-library, configuration, filesystem, and OS facts. Values of environment variables are never read into the snapshot. `--all-env` records all names and should be used deliberately because names reveal infrastructure vocabulary.

Capture performs no network requests and modifies no application files. It may create only the requested output file. Docker capture is a separate, explicit command.

Strict privacy removes application/home path prefixes and anonymizes hostname-like strings. Run `bootprint security audit PATH` before external sharing.
