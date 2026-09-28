// Stopgap until @platforma-sdk/r-builder pins pkgdepends itself: pkgdepends 0.9.1 resolves R's
// bundled packages to no URL, which fails collect-dependencies.R. Reinstall 0.9.0 after the basics.
import { readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';

const require = createRequire(import.meta.url);
const util = path.join(path.dirname(require.resolve('@platforma-sdk/r-builder/package.json')), 'scripts/lib/util.js');
const src = readFileSync(util, 'utf8');

if (src.includes('pkgdepends_0.9.0.tar.gz')) process.exit(0);

const anchor = `      '-e', ...quote(install(...basicRPackages), "'")],
    { paths: additionalPaths },
  );
`;
if (!src.includes(anchor)) {
  console.error(`patch-r-builder: installBasicRPackages changed in ${util}; drop this patch if r-builder pins pkgdepends`);
  process.exit(1);
}
const pin = `  runR(logger, rRoot,
    ['--no-echo',
      '-e', ...quote('install.packages("https://cloud.r-project.org/src/contrib/Archive/pkgdepends/pkgdepends_0.9.0.tar.gz", repos = NULL, type = "source")', "'")],
    { paths: additionalPaths },
  );
`;
writeFileSync(util, src.replace(anchor, anchor + pin));
console.log('patch-r-builder: pkgdepends pinned to 0.9.0');
