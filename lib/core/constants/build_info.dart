/// Manually updated on each push. Check this label in Profile screen
/// to verify which build is installed on a test device.
const String kBuildLabel = 'build-20260709-v1.1.1-r6';

const String kGitBranch = 'rematch-bug-investigation-az4n6h';

const String kAppVersion = '1.1.1+64';

/// Numeric build number of THIS build. Compared against the remote
/// `app_config/app.latestBuild` / `minBuild` to drive the in-app update notice.
/// Keep in sync with the `+NN` in [kAppVersion] and the AAB build number.
const int kBuildNumber = 64;
