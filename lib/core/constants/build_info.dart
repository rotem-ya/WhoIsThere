/// Manually updated on each push. Check this label in Profile screen
/// to verify which build is installed on a test device.
const String kBuildLabel = 'build-20260719-v1.4.0-candy';

const String kGitBranch = 'whoishere-visual-sound-rjcdzb';

const String kAppVersion = '1.4.0+100';

/// Numeric build number of THIS build. Compared against the remote
/// `app_config/app.latestBuild` / `minBuild` to drive the in-app update notice.
/// Keep in sync with the `+NN` in [kAppVersion] and the AAB build number.
const int kBuildNumber = 100;
