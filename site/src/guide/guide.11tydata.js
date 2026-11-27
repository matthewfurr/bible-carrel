// Every file in src/guide/ is a guide page: it takes the guide layout and sits at /guide/<slug>/.
// Its meta description is its lede unless the page sets one of its own.
export default {
  layout: 'layouts/guide.njk',
  eleventyComputed: {
    permalink: (data) => `/guide/${data.page.fileSlug}/`,
    description: (data) => data.description || data.lede,
  },
}
