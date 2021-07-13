/**
* ## Overview
*
* Serves files from a Cloud Storage bucket as if from a local filesystem.
*
* The basic flow is:

* 1. Determine bucket config and connect.
* 2. Listen.
* 3. Examine incoming requests.
*   3.1 If there's a suffix, pass handling to the file handler.
*   3.2 Everything else is assumed to be a directory reference. Pass handling to the directory indexer.
* 4. Back to listening.
*
*
*/
'use strict';

const projectId = process.env.GOOGLE_CLOUD_PROJECT;
console.log(`Servinging project ${projectId}`);

// setup storage stuff
const { Storage } = require('@google-cloud/storage');
const storage = new Storage();

const bucketId = process.env.BUCKET;
if (!bucketId) {
  throw new Error("No 'BUCKET_ID' environment variable found (or is empty).")
}
// Useful info for the logs.
console.log(`Connecting to bucket: ${bucketId}`);
const bucket = storage.bucket(bucketId);

// setup web server stuff
const express = require('express');
const app = express();
const PORT = process.env.PORT || 8080;

const commonImageFiles = /\.(jpg|png|gif)$/i;

const readBucketFile = async ({ path, res }) => {
  try {
    // first, check if file exists.
    const [ exists ] = await bucket.exists(path);
    if (exists) { // then read the file
      const file = await bucket.file(path);
      const reader = file.createReadStream();
      reader.on('error', (err) => {
        console.error(`Error while reading file: ${err}`);
        res.status(500).send(`Error reading file '${path}': ${err}`).end();
      })

      // is the file an image type?
      const imageMatchResults = path.match(commonImageFiles)
      if (path.match(commonImageFiles)) {
        res.writeHead(200,{'content-type':`image/${imageMatchResults[1].toLowerCase()}`});
      }

      reader.pipe(res);
    }
    else { // No such file, send 404
      res.status(404).send(`No such file: '${path}'`).end();
    }
  }
  catch (err) {
    console.error(`Caught exception while processing '${path}'.`);
    req.status(500).send(`Error reading: ${path}`).end()
  }
}

const startSlash = /^\//;
const endSlash = /\/$/;

const renderBreadcrumbs = (path) => {
  let html = "";
  if (path !== "") {
    // We remove the end slash to avoid an empty array element.
    const pathBits = path.replace(endSlash, '').split('/');
    // Each path bit represents a step back, but we step back into the prior element. E.g., if we see path "foo/bar",
    // so stepping back one takes us to foo and stepping back two takes us to the root. So we unshift a root element and
    // pop the last element to make everything match up.
    pathBits.unshift('&lt;root&gt;');
    pathBits.pop();
    // Now, we can generate the '../' step backs based on the depth of the path and the index of each elemeent.
    const pathBitsLength = pathBits.length;
    for (let i = 0; i < pathBits.length; i += 1) {
      html += `<a href="${Array(pathBitsLength - i).fill('..').join('/')}">${pathBits[i]}/</a> `
    }
  }
  
  return html;
}

const renderFiles = ({ path, files, folders, res }) => {
  // Our 'path' comes in full relative from the root. However, we want to show only the relative bits.
  const deprefixer = new RegExp(`${path}/?`);
  // open up with some boilerplace HTML
  let html =`<!doctype html>
<html>
<head>
  <meta charset="utf-8"/>
  <title>${path}</title>
  <!--[if lt IE 9]>
  <script src="//html5shim.googlecode.com/svn/trunk/html5.js"></script>
  <![endif]-->
</head>
<body>
  <h1>${path}</h1>
  <div id="breadcrumbs">
    ${renderBreadcrumbs(path)}
  </div>`;

  if (folders.length > 0) {
    html += `
  <h2 id="folders">Folders</h2>
    ${folders.length} total
  <ul>\n`;
    folders.forEach(folder => {
      const localRef = folder.replace(deprefixer, '');
      html += `    <li><a href="${encodeURIComponent(localRef.replace(endSlash, ''))}/">${localRef}</a></li>\n`;
    });

    html += `  </ul>`;
  }

  if (files && files.length > 0) {
    html += `
  <h2 id="files">Files</h2>
  ${files.length} total
  <ul>\n`;

    files.forEach(file => {
      const localRef = file.name.replace(deprefixer, '');
      html += `    <li><a href="${encodeURIComponent(localRef)}">${localRef}</a></li>\n`;
    });

    html += `  </ul>`;
  }
  html += `
</body>
</html>`;

  res.send(html).end();
}

const indexerQueryOptions = {
  delimiter: '/',
  includeTrailingDelimiter: true,
  autoPaginate: false // ?? necessary to see sub-folders
}

const indexBucket = ({ path, res }) => {
  if (path !== '' && !path.match(endSlash)) {
    res.redirect(301, `${path}/`).end();
  }

  let folders = [];
  const query = Object.assign({ prefix: path }, indexerQueryOptions)

  // OK, the Cloud Storage API (as of v5) is finicky and will only show you files in the 'await' version, e.g.:
  //
  // const [ files ] = await bucket.getFiles(query)
  //
  // In order to get the 'folders', you have to do to things:
  // 1) Inculde 'autoPaginate' in the query and
  // 2) Call using a callback method.
  //
  // In this form, you get to see the API response, which allows you to look at the 'prefixes' within the current search
  // prefix. These can be mapped to logical sub-folders in our bucket scheme.
  const indexPager = (err, files, nextQuery, apiResponse) => {
    if (err) {
      res.setStatus(500).send(`Error while processing results: ${err}`).end();
    }
    // all good!
    if (apiResponse.prefixes && apiResponse.prefixes.length > 0) {
      folders = folders.concat(apiResponse.prefixes);
    }

    if (nextQuery) {
      bucket.getFiles(nextQuery, indexPager);
    }
    else { // we've built up all the folders
      // If there's nothing here, treat as 404
      if ((!files || files.length === 0) && folders.length === 0) {
        res.status(404).send(`No such folder: '${path}'`).end();
      }
      else {
        renderFiles({ path, files, folders, res });
      }
    }
  }

  // here's where we actually kick everything off by doing the search.
  try {
    bucket.getFiles(query, indexPager);
  }
  catch (e) {
    res.status(500).send(`Explosion! ${e}`).end();
  }
}

// request processing setup

const commonProcessor = (render) => (req, res) => {
  // Cloud storage doesn't like an initial '/', so we remove any.
  const path = decodeURIComponent(req.path.replace(startSlash, ''));

  res.on('error', (err) => {
    console.error(`Error in the response output stream: ${err}`);
  })

  try {
    render({ path, res });
  }
  catch (e) {
    console.error(`Exception while rendering: ${e}`);
    res.status(500).send(`Explosion: ${err}`).end();
  }
}

const fileRegex = /.*\.[^./]+$/;
app.get(fileRegex, commonProcessor(readBucketFile));
// if it's not a file, maybe it's a bucket.
app.get('*', commonProcessor(indexBucket));

// start the server
app.listen(PORT, () => {
  console.log(`App listening on port ${PORT}`);
  console.log('Press Ctrl+C to quit.');
});

module.exports = app;
