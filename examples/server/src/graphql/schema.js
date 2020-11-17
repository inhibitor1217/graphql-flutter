const { gql, makeExecutableSchema } = require('apollo-server-koa');

const TODOS_KEY = 'TODOS';

const typeDef = gql`
    scalar Date

    type Todo {
        id: ID!
        title: String!
        content: String
        createdAt: Date!
        updatedAt: Date!
    }

    type Todos {
        id: ID!
        list(limit: Int, cursor: ID): [Todo]!
        count: Int!
    }

    type TodoOps {
        create(input: TodoInput!): Todo!
        update(id: ID!, input: TodoInput!): Todo
        delete(id: ID!): ID
    }

    input TodoInput {
        title: String!
        content: String
    }

    type Query {
        _version: String!
        Todo: Todos!
    }

    type Mutation {
        Todo: TodoOps!
    }
`;

let _count = 0;
function generateId() {
    return _count++;
}

const resolvers = {
    Query: {
        _version: () => '1',
        Todo: (parent, args, { storage }) => {
            const todos = storage.get(TODOS_KEY);

            return {
                id: () => 'Todos',
                count: () => todos?.length || 0,
                list: ({ cursor, limit = 3 }) => {
                    const all = todos?.map((id) => storage.get(id)) || [];
                    all.sort((one, other) => other.updatedAt - one.updatedAt);

                    const cursorItem = cursor ? storage.get(cursor) : null;
                    const filtered = all.filter((item) => !cursorItem || item.updatedAt < cursorItem.updatedAt);

                    return filtered.slice(0, limit);
                }
            };
        },
    },
    Mutation: {
        Todo: (parent, args, { storage }) => {
            return {
                create: ({ input: { title, content } }) => {
                    const todos = storage.get(TODOS_KEY);
                    const id = generateId();

                    const todo = { id, title, content, createdAt: Date.now(), updatedAt: Date.now() };

                    storage.set(id, todo);
                    storage.set(TODOS_KEY, todos ? [...todos, id] : [id]);

                    console.log(todo);

                    return todo;
                },
                update: ({ id, input: { title, content } }) => {
                    const todo = storage.get(id);

                    if (!todo) {
                        return null;
                    }

                    const updated = { ...todo, title: title || todo.title, content: content || todo.content, updatedAt: Date.now() };

                    storage.set(id, updated);

                    console.log(updated);

                    return updated;
                },
                delete: ({ id }) => {
                    const todos = storage.get(TODOS_KEY);

                    storage.set(TODOS_KEY, todos.filter((_id) => id.toString() !== _id.toString()));
                    storage.clear(id);

                    return id;
                },
            };
        },
    },
};

const schema = makeExecutableSchema({ typeDefs: typeDef, resolvers });

module.exports = schema;
