import React from 'react';
import OriginalTOC from '@theme-original/TOC';
import styles from './styles.module.css';

// Wrap Docusaurus' default right-side table of contents so users can collapse it.
// Keep the original implementation inside to minimize maintenance cost on upgrades.
export default function TOCWrapper(props: Record<string, unknown>) {
  return (
    <details className={styles.collapsibleToc} open>
      <summary className={styles.collapsibleTocSummary}>目次</summary>
      <div className={styles.collapsibleTocBody}>
        <OriginalTOC {...props} />
      </div>
    </details>
  );
}
