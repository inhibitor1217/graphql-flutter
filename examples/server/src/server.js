const Koa = require('koa');
const storage = require('./storage');
const schema = require('./graphql/schema');
const { ApolloServer } = require('apollo-server-koa');

const app = new Koa();

const apolloServer = new ApolloServer({
    schema,
    context: () => ({ storage }),
    playground: true,
});

app.use(apolloServer.getMiddleware());

app.listen(7008, () => {
    console.log('GraphQL test server is listening on port 7008 :)');
});
