// Set by the build: the Pages action supplies the repository's URL.
// While SITE_REPO_URL is empty the header's GitHub link is left out entirely.
export default {
  name: 'Bible Carrel',
  repoUrl: process.env.SITE_REPO_URL || '',
  year: 2026,
  holder: 'Matthew Furr',
}
