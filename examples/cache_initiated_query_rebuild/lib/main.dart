import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

void printCache(NormalizedInMemoryCache cache) {
  log(JsonEncoder.withIndent("  ").convert(cache.data));
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  NormalizedInMemoryCache _cache;
  ValueNotifier<GraphQLClient> _client = ValueNotifier(null);

  @override
  void initState() {
    super.initState();

    _cache =
        NormalizedInMemoryCache(dataIdFromObject: typenameDataIdFromObject);
    _client.value = GraphQLClient(
      cache: _cache,
      link: HttpLink(uri: 'http://localhost:7008/graphql'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GraphQLProvider(
      client: _client,
      child: MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: TodoListRoute(),
      ),
    );
  }
}

class TodoListRoute extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('TODO LIST')),
      body: Query(
        options: QueryOptions(
          documentNode: gql(r'''
            query TodoList($cursor: ID) {
              Todo {
                __typename
                id
                count
                list(cursor: $cursor) {
                  __typename
                  id
                  title
                  content
                  createdAt
                  updatedAt
                }
              }
            }
          '''),
        ),
        builder: (result, {refetch, fetchMore}) {
          if (result.loading) return Center(child: Text('Loading ...'));
          if (result.hasException) {
            print(result.exception);
            return Center(child: Text('Error :('));
          }

          final NormalizedInMemoryCache cache =
              GraphQLProvider.of(context).value.cache;
          printCache(cache);

          final int count = result.data['Todo']['count'];
          final List<dynamic> items = result.data['Todo']['list'];
          final cursor = items.last['id'];

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(count.toString()),
                SizedBox(height: 8.0),
                ...items
                    .map<Widget>(
                      (item) => Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['id']),
                            Text(item['title']),
                            Text(item['content']),
                            Text(DateTime.fromMillisecondsSinceEpoch(
                                    item['createdAt'])
                                .toLocal()
                                .toString()),
                            Text(DateTime.fromMillisecondsSinceEpoch(
                                    item['updatedAt'])
                                .toLocal()
                                .toString()),
                            FlatButton(
                              child: Text('SHOW DETAILS'),
                              onPressed: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => TodoDetailRoute(
                                      id: item['id'],
                                      title: item['title'],
                                      content: item['content']),
                                ));
                              },
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                FlatButton(
                  child: Text('FETCH MORE'),
                  onPressed: () {
                    fetchMore(FetchMoreOptions(
                      variables: {
                        'cursor': cursor,
                      },
                      updateQuery: (prev, cur) {
                        return Map<String, dynamic>.from(cur)
                          ..addAll({
                            'Todo': Map<String, dynamic>.from(cur['Todo'])
                              ..addAll({
                                'list': List<dynamic>.from(cur['Todo']['list'])
                                  ..insertAll(0, prev['Todo']['list']),
                              }),
                          });
                      },
                    ));
                  },
                ),
                Mutation(
                  options: MutationOptions(
                    documentNode: gql(r'''
                      mutation CreateTodo($title: String!, $content: String!) {
                        Todo {
                          create(input: {
                            title: $title,
                            content: $content
                          }) {
                            __typename
                            id
                            title
                            content
                            createdAt
                            updatedAt
                          }
                        }
                      }
                    '''),
                    update: (cache, result) {
                      final todo = result.data['Todo']['create'];

                      cache.write('Todo/${todo['id']}', todo);

                      final todos = cache.read('Todos/Todos');
                      final updated = {
                        ...todos,
                        'count': todos['count'] + 1,
                        'list': [
                          ...todos['list'],
                          todo,
                        ]
                      };

                      cache.write('Todos/Todos', updated);

                      printCache(cache);
                    },
                  ),
                  builder: (runMutation, result) => FlatButton(
                    child: Text('ADD TODO'),
                    onPressed: () {
                      runMutation({'title': 'TITLE', 'content': 'CONTENT'});
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class TodoDetailRoute extends StatelessWidget {
  final String id;
  final String title;
  final String content;
  TodoDetailRoute({
    @required this.id,
    @required this.title,
    @required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(id.toString())),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Mutation(
              options: MutationOptions(
                documentNode: gql(r'''
              mutation deleteTodo($id: ID!) {
                Todo {
                  delete(id: $id)
                }
              }
            '''),
                onCompleted: (data) {
                  Navigator.of(context).pop();
                },
                update: (cache, result) {
                  final deletedTodoId = result.data['Todo']['delete'];

                  final repo = cache.read('Todos/Todos');

                  final updated = {
                    ...repo,
                    'count': repo['count'] - 1,
                    'list': repo['list']
                        .where((item) => item['id'] != deletedTodoId)
                        .toList(),
                  };

                  cache.write('Todos/Todos', updated);

                  printCache(cache);
                },
              ),
              builder: (runMutation, result) => FlatButton(
                child: Text('Delete book: $id'),
                onPressed: () {
                  runMutation({'id': id});
                },
              ),
            ),
            SizedBox(height: 8.0),
            Mutation(
              options: MutationOptions(
                documentNode: gql(r'''
                  mutation updateTodo($id: ID!, $title: String!, $content: String!) {
                    Todo {
                      update(id: $id, input: {
                        title: $title
                        content: $content
                      }) {
                        __typename
                        id
                        title
                        content
                        createdAt
                        updatedAt
                      }
                    }
                  }
                '''),
                update: (cache, result) {
                  final todo = result.data['Todo']['update'];

                  cache.write('Todo/${todo['id']}', todo);

                  printCache(cache);
                },
              ),
              builder: (runMutation, result) => FlatButton(
                child: Text('Toggle content: $id'),
                onPressed: () {
                  runMutation({
                    'id': id,
                    'title': title,
                    'content':
                        content == 'CONTENT' ? 'CONTENT_OTHER' : 'CONTENT',
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
