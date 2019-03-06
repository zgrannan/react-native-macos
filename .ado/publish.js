require('shelljs/global');
const fs = require('fs');
const path = require('path');
const publishBranchName = process.env.publishBranchName;

const tempPublishBranch = `publish-${Data.now()}`;

const pkgJsonPath = path.resolve(__dirname, '../package.json');
let pkgJson = JSON.parse(fs.readFileSync(pkgJsonPath, 'utf8'));

let releaseVersion = pkgJson.version;

const versionGroups = /(.*-microsoft\.)([0-9]*)/.exec(releaseVersion);
if (versionGroups) {
  releaseVersion = versionGroups[1] + (parseInt(versionGroups[2])+1);
} else {
  if (releaseVersion.indexOf('-') === -1)
  {
    releaseVersion = releaseVersion + '-microsoft.0';
  }
  else
  {
    echo('Invalid version to publish');
    exit(1);
  }
}

pkgJson.version = releaseVersion;
fs.writeFileSync(pkgJsonPath, JSON.stringify(pkgJson, null, 2));
echo(`Updating package.json to version ${releaseVersion}`);

if (exec(`git add ${pkgJsonPath}`).code) {
  echo('Failed to git add package.json');
  exit(1);
}

if (exec(`git commit -m "Applying package update to v${releaseVersion}`).code) {
  echo('Failed to commit package.json');
  exit(1);
}

if (exec(`git push origin HEAD:${tempPublishBranch} --follow-tags --verbose`).code) {
  echo('Failed to push publish branch');
  exit(1);
}

/*
// -------- Generating Android Artifacts with JavaDoc
if (exec('./gradlew :ReactAndroid:installArchives').code) {
  echo('Could not generate artifacts');
  exit(1);
}
*/

// undo uncommenting javadoc setting
exec('git checkout ReactAndroid/gradle.properties');


// Configure npm to publish to internal feed
fs.writeFileSync(path.resolve(__dirname, '../.npmrc'), `registry=${process.env.publishnpmfeed}\nalways-auth=true`);

if (exec(`npm publish`).code) {
  echo('Failed to publish package to npm');
  exit(1);
} else {
  echo(`Published to npm ${releaseVersion}`);
  exit(0);
}

if (exec(`git tag v${releaseVersion}`).code) {
  echo('Failed to tag git.');
  exit(1);
};

if (exec(`git push origin HEAD:${tempPublishBranch} --follow-tags --verbose`).code) {
  echo('Failed to push tags to publish branch');
  exit(1);
}

if (exec(`git checkout ${publishBranchName}`).code) {
  echo(`Failed to checkout ${publishBranchName}`);
  exit(1);
}

if (exec('git pull origin ${publishBranchName}').code) {
  echo('Failed to pull to latest');
  exit(1);
};

if (exec('git merge ${publishBranchName} --no-edit').code) {
  echo('Failed to pull to latest');
  exit(1);
};

if (exec('git push origin HEAD:${publishBranchName} --follow-tags --verbose').code) {
  echo(`Failed push temp publish branch to ${publishBranchName}`);
  exit(1);
};

if (exec('git branch -d ${tempPublishBranch}').code) {
  echo('Failed to delete temp publish branch');
  exit(1);
};

if (exec('git push origin --delete -d ${tempPublishBranch}').code) {
  echo('Failed to push delete temp publish branch');
  exit(1);
};