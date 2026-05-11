import React from 'react';
import ComponentCreator from '@docusaurus/ComponentCreator';

export default [
  {
    path: '/',
    component: ComponentCreator('/', '692'),
    routes: [
      {
        path: '/',
        component: ComponentCreator('/', 'ea6'),
        routes: [
          {
            path: '/',
            component: ComponentCreator('/', 'abb'),
            routes: [
              {
                path: '/api-specification',
                component: ComponentCreator('/api-specification', 'e77'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/',
                component: ComponentCreator('/', '322'),
                exact: true,
                sidebar: "tutorialSidebar"
              }
            ]
          }
        ]
      }
    ]
  },
  {
    path: '*',
    component: ComponentCreator('*'),
  },
];
