# (WIP) Hibiki

A small Discord interaction proxy that handles request validation.

## Configuration

The following envionmental variables must be set.

| Envionmental Variable | Type           | Description                                                              |
| --------------------- | -------------- | ------------------------------------------------------------------------ |
| `HIBIKI_PUBLIC_KEY`   | `string`       | Public key found on your application the Discord Developer Portal        |
| `HIBIKI_MODE`         | `HTTP` or `MQ` | Direct http request to your interaction handler or push to message queue |

Additionally, these envionmental variables must be set if `HIBIKI_TYPE` set as `HTTP`.
| Envionmental Variable | Type           | Description                                                              |
| --------------------- | -------------- | ------------------------------------------------------------------------ |
| `HIBIKI_APP_HOST`     | `string`       | Host of your interaction handler service                                 |
| `HIBIKI_APP_PORT`     | `u16`          | Port of your interaction handler service, number between 1024 and 65535  |

Alternatively, these envionmental variables must be set if `HIBIKI_TYPE` set as `MQ`.
| Envionmental Variable | Type           | Description   |
| --------------------- | -------------- | ------------- |
| `HIBIKI_MQ_URI`       | `string`       | Miniqueue URI |

The following envionmental variables are optional.
| Envionmental Variable | Type           | Default   | Description                                                 |
| --------------------- | -------------- | --------- | ----------------------------------------------------------- |
| `HIBIKI_HOST`         | `string`       | `0.0.0.0` | Host for Hibiki to listen on                                |
| `HIBIKI_PORT`         | `u16`          | `4242`    | Port for Hibiki to listen on, number between 1024 and 65535 |
