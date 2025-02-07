// main.ts

import { initServer, createExpressEndpoints } from '@ts-rest/express';
import { generateOpenApi } from '@ts-rest/open-api';
import express from 'express';
import bodyParser from 'body-parser';
import * as swaggerUi from 'swagger-ui-express';
import { contract } from './contract';
const app = express();


const port = process.env.port || 3000;

//app.use(cors());
app.use(bodyParser.urlencoded({ extended: false }));
app.use(bodyParser.json());

const s = initServer();

const acaenvdomain = process.env.CONTAINER_APP_ENV_DNS_SUFFIX || `localhost:${port}`;

const router = s.router(contract, {
  getPost: async ({ params: { id }, query: { url } }) => {

    let post = { id: id, title: "keith", body: "keith" }
    if (id.startsWith ("app") || url) {
      // fetch from url
      const fetchurl = url || `https://${id}.${acaenvdomain}/posts/1`
      try {
        console.log (`fetching from ${fetchurl}`)
        const response = await fetch(fetchurl);
        if (response.ok)
          post = await response.json() as { id: string, title: string, body: string };
        else {
          console.log (`not ok response ${await response.text}`)
        }
      } catch (error) {
        console.error(error);
        post = { id: "error", title: `error ${error}`, body: `fetching ${fetchurl}` }
      }
    } 
      
    return {
      status: 200,
      body: post,
    };
    
  },
  createPost: async ({ body }) => {
    const post = { id: "keith", title: "keith", body: "keith" }

    return {
      status: 201,
      body: post,
    };
  },
});

createExpressEndpoints(contract, router, app);

const openApiDocument = generateOpenApi(contract, {
  info: {
    title: 'Posts API',
    version: '1.0.0',
  },
});

app.use('/api-docs/ui', swaggerUi.serve, swaggerUi.setup(openApiDocument));

app.get('/api-docs/openapi.json', (req, res) => {
  res.json(openApiDocument);
})


const server = app.listen(port, () => {
  console.log(`Listening at http://localhost:${port}`);
});
