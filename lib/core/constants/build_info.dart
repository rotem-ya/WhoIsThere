/// Manually updated on each push. Check this label in Profile screen
/// to verify which build is installed on a test device.
const String kBuildLabel = 'build-20260716-v1.3.2-hotfix2';

const String kGitBranch = 'whothere-v111-launch-iqkbq2';

const String kAppVersion = '1.3.2+40';

/// Numeric build number of THIS build. Compared against the remote
/// `app_config/app.latestBuild` / `minBuild` to drive the in-app update notice.
/// Keep in sync with the `+NN` in [kAppVersion] and the AAB build number.
const int kBuildNumber = 70;
