import React from 'react';
import ComponentCreator from '@docusaurus/ComponentCreator';

export default [
  {
    path: '/',
    component: ComponentCreator('/', '7c1'),
    routes: [
      {
        path: '/',
        component: ComponentCreator('/', '48c'),
        routes: [
          {
            path: '/',
            component: ComponentCreator('/', 'd95'),
            routes: [
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
