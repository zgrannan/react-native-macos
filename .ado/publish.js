require('shelljs/global');
const fs = require('fs');
const path = require('path');


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

/*
// -------- Generating Android Artifacts with JavaDoc
if (exec('./gradlew :ReactAndroid:installArchives').code) {
  echo('Could not generate artifacts');
  exit(1);
}
*/

// undo uncommenting javadoc setting
exec('git checkout ReactAndroid/gradle.properties');

if (exec(`git tag v${releaseVersion}`).code) {
  echo('Failed to tag git.');
  exit(1);
};
if (exec('git pull').code) {
  echo('Failed to pull to latest');
  exit(1);
};

if (exec(`git add ${pkgJsonPath}`).code) {
  echo('Failed to git add package.json');
  exit(1);
}

// Publish to our internal feed
fs.writeFileSync(path.resolve(__dirname, '../.npmrc'), `registry=${process.env.publishnpmfeed}\nalways-auth=true`);

if (exec(`git commit -m "Publish build v${releaseVersion}`).code) {
  echo('Failed to commit pacakge.json');
  exit(1);
}

if (exec(`git push --tags`).code) {
  echo('Failed to push changes to origin');
  exit(1);
};

if (exec(`npm publish`).code) {
  echo('Failed to publish package to npm');
  exit(1);
} else {
  echo(`Published to npm ${releaseVersion}`);
  exit(0);
}